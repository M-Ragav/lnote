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
import android.graphics.Typeface
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
            if (ids.isEmpty()) return

            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }

            val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                component = ComponentName(context, CalendarWidgetProvider::class.java)
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(updateIntent)
        }

        private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.calendar_widget)

            // Read attendance data
            val dayDurations = loadDayDurations(context)

            // Generate Heat Map Bitmap with Image 1 style: numbered cells, month headers, right day labels
            val weeks = 15
            val (bitmap, totalMinutes) = drawCalendarHeatmap(dayDurations, weeks)
            views.setImageViewBitmap(R.id.iv_calendar_canvas, bitmap)

            // Total hours logged
            val hours = totalMinutes / 60
            val mins = totalMinutes % 60
            views.setTextViewText(R.id.tv_total_logged, "${hours}h ${mins}m logged")

            // Click to open main app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_calendar_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun getAttendanceFile(context: Context): File? {
            val candidates = listOf(
                File(context.filesDir.parentFile, "app_flutter/attendance_data.json"),
                File(context.filesDir, "attendance_data.json"),
                File(context.filesDir, "app_flutter/attendance_data.json")
            )
            for (file in candidates) {
                if (file.exists() && file.length() > 0) return file
            }
            return candidates[0]
        }

        private fun loadDayDurations(context: Context): Map<String, Int> {
            val durations = mutableMapOf<String, Int>()
            try {
                val file = getAttendanceFile(context) ?: return durations
                if (!file.exists()) return durations

                val jsonStr = file.readText()
                if (jsonStr.isBlank()) return durations

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
            // High-density scaling for crisp text on high-DPI phone displays
            val cellWidth = 32f
            val cellHeight = 30f
            val cellGap = 5f
            val cornerRadius = 6f
            val rightLabelWidth = 44f
            val topHeaderHeight = 24f

            val totalWidth = (weeksCount * (cellWidth + cellGap) + rightLabelWidth + 12).toInt()
            val totalHeight = (7 * (cellHeight + cellGap) + topHeaderHeight + 8).toInt()

            val bitmap = Bitmap.createBitmap(totalWidth, totalHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val cellPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            val numPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textSize = 13f
            }
            val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#9CA3AF")
                textSize = 12f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            }
            val monthHeaderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#D1D5DB")
                textSize = 13f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            }

            val startX = 6f
            val startY = topHeaderHeight + 4f

            val today = Calendar.getInstance()
            val todayDateOnly = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            // Calculate start date: aligned to Monday, weeksCount weeks back
            val cal = Calendar.getInstance()
            while (cal.get(Calendar.DAY_OF_WEEK) != Calendar.SUNDAY) {
                cal.add(Calendar.DAY_OF_YEAR, 1)
            }
            cal.add(Calendar.WEEK_OF_YEAR, -(weeksCount - 1))
            while (cal.get(Calendar.DAY_OF_WEEK) != Calendar.MONDAY) {
                cal.add(Calendar.DAY_OF_YEAR, -1)
            }

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val monthFormat = SimpleDateFormat("MMM", Locale.US)
            val monthYearFormat = SimpleDateFormat("MMM yyyy", Locale.US)

            var totalMinutes = 0
            var lastMonth = -1

            // Save start for drawing week columns
            val tempCal = cal.clone() as Calendar

            for (w in 0 until weeksCount) {
                val colX = startX + w * (cellWidth + cellGap)
                val firstDayOfWeek = tempCal.clone() as Calendar

                // Check for month header change
                val currentMonth = firstDayOfWeek.get(Calendar.MONTH)
                if (currentMonth != lastMonth) {
                    val label = if (w == 0) monthYearFormat.format(firstDayOfWeek.time) else monthFormat.format(firstDayOfWeek.time)
                    canvas.drawText(label, colX, topHeaderHeight - 4f, monthHeaderPaint)
                    lastMonth = currentMonth
                }

                for (d in 0 until 7) {
                    val rowY = startY + d * (cellHeight + cellGap)
                    val date = tempCal.time
                    val dateStr = dateFormat.format(date)
                    val isFuture = tempCal.after(todayDateOnly)
                    val dayNum = tempCal.get(Calendar.DAY_OF_MONTH).toString()

                    val mins = if (isFuture) 0 else (durations[dateStr] ?: 0)
                    if (!isFuture) totalMinutes += mins

                    // Reference colors from Image 1:
                    // Active: Vibrant Coral-Orange (#FF5722 / #F4511E)
                    // Inactive: Dark slate grey (#2E3036)
                    // Future: Very faint dark (#1E2024)
                    val (bgColor, numColor) = when {
                        isFuture -> Pair(Color.parseColor("#1C1E23"), Color.parseColor("#4B5162"))
                        mins > 0 -> Pair(Color.parseColor("#FF5722"), Color.parseColor("#FFFFFF"))
                        else -> Pair(Color.parseColor("#2E3036"), Color.parseColor("#C4C7D2"))
                    }

                    cellPaint.color = bgColor
                    val rect = RectF(colX, rowY, colX + cellWidth, rowY + cellHeight)
                    canvas.drawRoundRect(rect, cornerRadius, cornerRadius, cellPaint)

                    // Draw day number centered in cell
                    numPaint.color = numColor
                    val textY = rowY + (cellHeight / 2f) - ((numPaint.descent() + numPaint.ascent()) / 2f)
                    canvas.drawText(dayNum, colX + (cellWidth / 2f), textY, numPaint)

                    tempCal.add(Calendar.DAY_OF_YEAR, 1)
                }
            }

            // Draw day of week labels on the right (Mon, Tue, Wed, Thu, Fri, Sat, Sun) as in Image 1
            val dayNames = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
            val rightLabelX = startX + weeksCount * (cellWidth + cellGap) + 4f

            for (d in 0 until 7) {
                val rowY = startY + d * (cellHeight + cellGap)
                val labelY = rowY + (cellHeight / 2f) - ((labelPaint.descent() + labelPaint.ascent()) / 2f)
                canvas.drawText(dayNames[d], rightLabelX, labelY, labelPaint)
            }

            return Pair(bitmap, totalMinutes)
        }
    }
}
