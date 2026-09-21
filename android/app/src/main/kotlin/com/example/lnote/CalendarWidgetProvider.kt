package com.example.lnote

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, CalendarWidgetProvider::class.java))
            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }
        }

        private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.calendar_widget)

            // Read attendance data
            val dayDurations = loadDayDurations(context)

            // Generate Heat Map Bitmap
            val weeks = 14
            val (bitmap, totalMinutes) = drawCalendarHeatmap(dayDurations, weeks)
            views.setImageViewBitmap(R.id.iv_calendar_canvas, bitmap)

            // Total hours logged
            val hours = totalMinutes / 60
            val mins = totalMinutes % 60
            views.setTextViewText(R.id.tv_total_logged, "${hours}h ${mins}m")

            // Click to open main app
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_calendar_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun loadDayDurations(context: Context): Map<String, Int> {
            val durations = mutableMapOf<String, Int>()
            try {
                // Check both filesDir and app_flutter subfolder
                var file = File(context.filesDir, "attendance_data.json")
                if (!file.exists()) {
                    file = File(context.filesDir, "app_flutter/attendance_data.json")
                }
                if (!file.exists()) return durations

                val jsonStr = file.readText()
                val jsonArray = JSONArray(jsonStr)
                val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)

                for (i in 0 until jsonArray.length()) {
                    val dayObj = jsonArray.getJSONObject(i)
                    val date = dayObj.optString("date", "")
                    val sessions = dayObj.optJSONArray("sessions") ?: continue

                    var dayTotalSec = 0L
                    for (j in 0 until sessions.length()) {
                        val session = sessions.getJSONObject(j)
                        val inTimeStr = session.optString("inTime", "")
                        val outTimeStr = session.optString("outTime", "")

                        if (inTimeStr.isNotEmpty() && outTimeStr.isNotEmpty() && outTimeStr != "null") {
                            val inTime = parseIso(inTimeStr, isoFormat)
                            val outTime = parseIso(outTimeStr, isoFormat)
                            if (inTime != null && outTime != null && outTime.after(inTime)) {
                                dayTotalSec += (outTime.time - inTime.time) / 1000
                            }
                        }
                    }
                    durations[date] = (dayTotalSec / 60).toInt()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
            return durations
        }

        private fun parseIso(str: String, format: SimpleDateFormat): Date? {
            return try {
                val cleaned = if (str.length > 19) str.substring(0, 19) else str
                format.parse(cleaned)
            } catch (e: Exception) {
                null
            }
        }

        private fun drawCalendarHeatmap(durations: Map<String, Int>, weeksCount: Int): Pair<Bitmap, Int> {
            val cellWidth = 24f
            val cellHeight = 24f
            val cellGap = 6f
            val cornerRadius = 6f

            val totalWidth = (weeksCount * (cellWidth + cellGap) + 40).toInt()
            val totalHeight = (7 * (cellHeight + cellGap) + 30).toInt()

            val bitmap = Bitmap.createBitmap(totalWidth, totalHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#8E8E93")
                textSize = 14f
            }

            // Draw day labels on the left (M, W, F)
            canvas.drawText("M", 4f, 24f + cellHeight, textPaint)
            canvas.drawText("W", 4f, 24f + (cellHeight + cellGap) * 3, textPaint)
            canvas.drawText("F", 4f, 24f + (cellHeight + cellGap) * 5, textPaint)

            val startX = 24f
            val startY = 20f

            val cal = Calendar.getInstance()
            // End date is today
            val today = Calendar.getInstance()
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(today.time)

            // Align end of grid to current week's Sunday
            while (cal.get(Calendar.DAY_OF_WEEK) != Calendar.SUNDAY) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            // Go back weeksCount weeks
            cal.add(Calendar.WEEK_OF_YEAR, -(weeksCount - 1))
            // Start on Monday
            while (cal.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) {
                cal.add(Calendar.DAY_OF_YEAR, -1)
            }

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            var totalMinutes = 0

            for (w in 0 until weeksCount) {
                val x = startX + w * (cellWidth + cellGap)

                for (d in 0 until 7) {
                    val y = startY + d * (cellHeight + cellGap)
                    val date = cal.time
                    val dateStr = dateFormat.format(date)
                    val isFuture = date.after(today.time)

                    val mins = if (isFuture) 0 else durations[dateStr] ?: 0
                    if (!isFuture) totalMinutes += mins

                    // Color based on activity level
                    paint.color = when {
                        isFuture -> Color.parseColor("#141418")
                        mins == 0 -> Color.parseColor("#262630")
                        mins < 120 -> Color.parseColor("#125E49")
                        mins < 240 -> Color.parseColor("#0E8F6F")
                        mins < 420 -> Color.parseColor("#00B896")
                        else -> Color.parseColor("#00E5C3")
                    }

                    val rect = RectF(x, y, x + cellWidth, y + cellHeight)
                    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, paint)

                    cal.add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            return Pair(bitmap, totalMinutes)
        }
    }
}
