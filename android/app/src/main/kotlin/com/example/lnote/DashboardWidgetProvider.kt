package com.example.lnote

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class DashboardWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == ACTION_CLOCK_IN) {
            handleClockIn(context)
            updateAll(context)
            CalendarWidgetProvider.updateAll(context)
        } else if (action == ACTION_CLOCK_OUT) {
            handleClockOut(context)
            updateAll(context)
            CalendarWidgetProvider.updateAll(context)
        }
    }

    companion object {
        const val ACTION_CLOCK_IN = "com.example.lnote.ACTION_CLOCK_IN"
        const val ACTION_CLOCK_OUT = "com.example.lnote.ACTION_CLOCK_OUT"

        fun updateAll(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, DashboardWidgetProvider::class.java))
            if (ids.isEmpty()) return

            for (id in ids) {
                updateWidget(context, appWidgetManager, id)
            }

            val updateIntent = Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                component = ComponentName(context, DashboardWidgetProvider::class.java)
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(updateIntent)
        }

        private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.dashboard_widget)

            val (sessionsCount, workMinutes, isActive, daysCount) = loadTodayStats(context)

            // Formatted values
            val hours = workMinutes / 60
            val mins = workMinutes % 60
            val workTimeStr = if (hours > 0) "${hours}h ${mins}m" else "${mins}m"
            val todayDateStr = SimpleDateFormat("EEEE, MMM d", Locale.US).format(Date())

            views.setTextViewText(R.id.tv_dashboard_date, todayDateStr)
            views.setTextViewText(R.id.tv_days_count, daysCount.toString())
            views.setTextViewText(R.id.tv_sessions_count, sessionsCount.toString())
            views.setTextViewText(R.id.tv_work_time, workTimeStr)

            // Status label
            if (isActive) {
                views.setTextViewText(R.id.tv_session_status, "● ACTIVE")
                views.setTextColor(R.id.tv_session_status, Color.parseColor("#4ADE80"))
            } else {
                views.setTextViewText(R.id.tv_session_status, "IDLE")
                views.setTextColor(R.id.tv_session_status, Color.parseColor("#8E8E93"))
            }

            // Click to open main app
            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val appPendingIntent = PendingIntent.getActivity(
                context, 0, appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_dashboard_root, appPendingIntent)

            // Clock IN PendingIntent
            val inIntent = Intent(context, DashboardWidgetProvider::class.java).apply {
                this.action = ACTION_CLOCK_IN
            }
            val inPendingIntent = PendingIntent.getBroadcast(
                context, 101, inIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_clock_in, inPendingIntent)

            // Clock OUT PendingIntent
            val outIntent = Intent(context, DashboardWidgetProvider::class.java).apply {
                this.action = ACTION_CLOCK_OUT
            }
            val outPendingIntent = PendingIntent.getBroadcast(
                context, 102, outIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_clock_out, outPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun getAttendanceFile(context: Context): File {
            val candidates = listOf(
                File(context.filesDir.parentFile, "app_flutter/attendance_data.json"),
                File(context.filesDir, "attendance_data.json"),
                File(context.filesDir, "app_flutter/attendance_data.json")
            )
            for (file in candidates) {
                if (file.exists() && file.length() > 0) return file
            }
            // Ensure parent directory exists for primary location
            val primary = candidates[0]
            primary.parentFile?.mkdirs()
            return primary
        }

        private fun loadTodayStats(context: Context): Quad<Int, Int, Boolean, Int> {
            var sessionsCount = 0
            var workMinutes = 0
            var isActive = false
            var totalDays = 0

            try {
                val file = getAttendanceFile(context)
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

                if (file.exists() && file.length() > 0) {
                    val jsonArray = JSONArray(file.readText())
                    totalDays = jsonArray.length()
                    val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)

                    for (i in 0 until jsonArray.length()) {
                        val dayObj = jsonArray.getJSONObject(i)
                        val date = dayObj.optString("date", "")
                        val sessions = dayObj.optJSONArray("sessions") ?: continue

                        if (date == todayStr) {
                            sessionsCount = sessions.length()
                            var totalSec = 0L

                            for (j in 0 until sessions.length()) {
                                val session = sessions.getJSONObject(j)
                                val inTimeStr = session.optString("inTime", "")
                                val outTimeStr = session.optString("outTime", "")

                                if (outTimeStr.isEmpty() || outTimeStr == "null") {
                                    isActive = true
                                } else {
                                    val inTime = parseIso(inTimeStr, isoFormat)
                                    val outTime = parseIso(outTimeStr, isoFormat)
                                    if (inTime != null && outTime != null && outTime.after(inTime)) {
                                        totalSec += (outTime.time - inTime.time) / 1000
                                    }
                                }
                            }
                            workMinutes = (totalSec / 60).toInt()
                        }
                    }
                }

                // Check birthday in shared prefs for days lived
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val bdayStr = prefs.getString("flutter.user_birthday", null)
                if (bdayStr != null) {
                    try {
                        val bday = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(bdayStr.substring(0, 10))
                        if (bday != null) {
                            val diff = (Date().time - bday.time) / (1000 * 60 * 60 * 24)
                            totalDays = (diff + 1).toInt()
                        }
                    } catch (ignored: Exception) {}
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            return Quad(sessionsCount, workMinutes, isActive, totalDays)
        }

        private fun parseIso(str: String, format: SimpleDateFormat): Date? {
            return try {
                val cleaned = if (str.length > 19) str.substring(0, 19) else str
                format.parse(cleaned)
            } catch (e: Exception) {
                null
            }
        }

        private fun handleClockIn(context: Context) {
            try {
                val file = getAttendanceFile(context)
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())

                val jsonArray = if (file.exists() && file.length() > 0) {
                    JSONArray(file.readText())
                } else {
                    JSONArray()
                }

                var todayObj: JSONObject? = null
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    if (obj.optString("date") == todayStr) {
                        todayObj = obj
                        break
                    }
                }

                if (todayObj == null) {
                    todayObj = JSONObject().apply {
                        put("date", todayStr)
                        put("sessions", JSONArray())
                    }
                    jsonArray.put(todayObj)
                }

                val sessions = todayObj.getJSONArray("sessions")
                val newSession = JSONObject().apply {
                    put("inTime", nowIso)
                    put("outTime", JSONObject.NULL)
                }
                sessions.put(newSession)

                file.writeText(jsonArray.toString(2))
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        private fun handleClockOut(context: Context) {
            try {
                val file = getAttendanceFile(context)
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())

                if (!file.exists()) return
                val jsonArray = JSONArray(file.readText())

                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.getJSONObject(i)
                    if (obj.optString("date") == todayStr) {
                        val sessions = obj.optJSONArray("sessions") ?: continue
                        if (sessions.length() > 0) {
                            val lastSession = sessions.getJSONObject(sessions.length() - 1)
                            val outTime = lastSession.optString("outTime", "")
                            if (outTime.isEmpty() || outTime == "null") {
                                lastSession.put("outTime", nowIso)
                            }
                        }
                        break
                    }
                }

                file.writeText(jsonArray.toString(2))
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}

data class Quad<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
