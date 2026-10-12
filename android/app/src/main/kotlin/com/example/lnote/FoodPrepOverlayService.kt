package com.example.lnote

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class FoodPrepOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_CLOSE) {
            removeFloatingView()
            stopSelf()
            return START_NOT_STICKY
        }

        showFloatingWindow(intent)
        return START_NOT_STICKY
    }

    private fun showFloatingWindow(intent: Intent?) {
        if (floatingView != null) {
            removeFloatingView()
        }

        // 1. Maintain foreground service contract on Android 8+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val notif = FoodPrepAlarmReceiver.buildNotification(this)
                startForeground(FoodPrepAlarmReceiver.NOTIFICATION_ID, notif)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 2. Play notification ringtone
        try {
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, soundUri)
            ringtone?.play()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val density = resources.displayMetrics.density
        val widthPx = (350 * density).toInt()

        val params = WindowManager.LayoutParams(
            widthPx,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            x = 0
            y = 0
        }

        // ─── Build the root card layout (Modern dark theme matching LNote) ───
        val rootCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#121218"))
                cornerRadius = 22 * density
                setStroke((1.2 * density).toInt(), Color.parseColor("#272736"))
            }
            background = bg
            setPadding((18 * density).toInt(), (14 * density).toInt(), (18 * density).toInt(), (18 * density).toInt())
            elevation = 20 * density
        }

        // Drag Handle Pill
        val dragPill = View(this).apply {
            val pillBg = GradientDrawable().apply {
                setColor(Color.parseColor("#444455"))
                cornerRadius = 2 * density
            }
            background = pillBg
        }
        val pillParams = LinearLayout.LayoutParams((36 * density).toInt(), (4 * density).toInt()).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            bottomMargin = (12 * density).toInt()
        }
        rootCard.addView(dragPill, pillParams)

        // ─── Header: Draggable ───
        val headerLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, (10 * density).toInt())
        }

        // Icon box
        val iconBox = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            val iconBg = GradientDrawable().apply {
                colors = intArrayOf(Color.parseColor("#00C9A7"), Color.parseColor("#00D4FF"))
                orientation = GradientDrawable.Orientation.TL_BR
                cornerRadius = 10 * density
            }
            background = iconBg
            val checkTv = TextView(this@FoodPrepOverlayService).apply {
                text = "✓"
                setTextColor(Color.WHITE)
                textSize = 14f
                paint.isFakeBoldText = true
            }
            addView(checkTv)
        }
        val iconParams = LinearLayout.LayoutParams((32 * density).toInt(), (32 * density).toInt()).apply {
            marginEnd = (10 * density).toInt()
        }
        headerLayout.addView(iconBox, iconParams)

        val titleCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
        }

        val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        val tomorrowDayName = SimpleDateFormat("EEEE", Locale.US).format(tomorrowCal.time)
        val tomorrowDateStr = SimpleDateFormat("MMM d", Locale.US).format(tomorrowCal.time)

        val titleText = TextView(this).apply {
            text = "Food Preparation • $tomorrowDayName"
            textSize = 14.5f
            setTextColor(Color.WHITE)
            paint.isFakeBoldText = true
        }
        val subText = TextView(this).apply {
            text = "Checklist for tomorrow ($tomorrowDateStr)"
            textSize = 11.5f
            setTextColor(Color.parseColor("#9E9EA8"))
        }
        titleCol.addView(titleText)
        titleCol.addView(subText)

        // Close button (X)
        val closeBtn = TextView(this).apply {
            text = "✕"
            textSize = 15f
            setTextColor(Color.parseColor("#8E8E98"))
            setPadding((8 * density).toInt(), (4 * density).toInt(), (8 * density).toInt(), (4 * density).toInt())
            setOnClickListener {
                removeFloatingView()
                stopSelf()
            }
        }

        headerLayout.addView(titleCol)
        headerLayout.addView(closeBtn)

        // Drag listener on header
        headerLayout.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()
                        try {
                            windowManager?.updateViewLayout(rootCard, params)
                        } catch (_: Exception) {}
                        return true
                    }
                }
                return false
            }
        })

        rootCard.addView(headerLayout)

        // Divider
        val divider = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (1 * density).toInt()).apply {
                bottomMargin = (10 * density).toInt()
            }
            setBackgroundColor(Color.parseColor("#262634"))
        }
        rootCard.addView(divider)

        // ─── Foods List (ScrollView) ───
        val scrollView = ScrollView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                (210 * density).toInt()
            )
        }

        val listLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }

        // Get tomorrow foods either from Intent extra or storage file
        val itemsJsonStr = intent?.getStringExtra(EXTRA_ITEMS_JSON)
        val foodList = loadTomorrowFoods(itemsJsonStr, tomorrowCal)

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        if (foodList.isEmpty()) {
            val emptyTv = TextView(this).apply {
                text = "No foods scheduled for tomorrow!\nAdd foods in LNote under Food tab."
                textSize = 12.5f
                setTextColor(Color.parseColor("#71717A"))
                gravity = Gravity.CENTER
                setPadding(0, (24 * density).toInt(), 0, (24 * density).toInt())
            }
            listLayout.addView(emptyTv)
        } else {
            for (food in foodList) {
                val itemCard = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    val iBg = GradientDrawable().apply {
                        setColor(Color.parseColor("#181822"))
                        cornerRadius = 10 * density
                        setStroke((1 * density).toInt(), Color.parseColor("#262634"))
                    }
                    background = iBg
                    setPadding((8 * density).toInt(), (6 * density).toInt(), (10 * density).toInt(), (6 * density).toInt())
                }
                val cardParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    bottomMargin = (6 * density).toInt()
                }

                val cb = CheckBox(this).apply {
                    isChecked = isFoodChecked(prefs, food.id)
                    setOnCheckedChangeListener { _, checked ->
                        setFoodChecked(prefs, food.id, checked)
                    }
                }

                val textCol = LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0f)
                }

                val nameTv = TextView(this).apply {
                    val countStr = if (food.count.isNotEmpty()) " (${food.count})" else ""
                    text = "${food.name}$countStr"
                    textSize = 13f
                    setTextColor(Color.WHITE)
                    paint.isFakeBoldText = true
                }

                val detailTv = TextView(this).apply {
                    val notesStr = if (food.notes.isNotEmpty()) " • ${food.notes}" else ""
                    text = "${food.mealType} • By ${food.deadline}$notesStr"
                    textSize = 11f
                    setTextColor(Color.parseColor("#9E9EA8"))
                }

                textCol.addView(nameTv)
                textCol.addView(detailTv)

                itemCard.addView(cb)
                itemCard.addView(textCol)
                listLayout.addView(itemCard, cardParams)
            }
        }

        scrollView.addView(listLayout)
        rootCard.addView(scrollView)

        // Bottom Divider
        val bottomDivider = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, (1 * density).toInt()).apply {
                topMargin = (8 * density).toInt()
                bottomMargin = (12 * density).toInt()
            }
            setBackgroundColor(Color.parseColor("#262634"))
        }
        rootCard.addView(bottomDivider)

        // ─── Action Buttons: Temporary Skip & Skip & Done ───
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        // Temporary Skip Button (10 min snooze)
        val tempSkipBtn = Button(this).apply {
            text = "Temp Skip\n(+10m)"
            textSize = 11f
            setTextColor(Color.parseColor("#FBBF24"))
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#241E14"))
                cornerRadius = 12 * density
                setStroke((1 * density).toInt(), Color.parseColor("#5A3E12"))
            }
            background = bg
            layoutParams = LinearLayout.LayoutParams(0, (46 * density).toInt(), 1.0f).apply {
                marginEnd = (6 * density).toInt()
            }
            setOnClickListener {
                handleTempSkip(this@FoodPrepOverlayService)
                Toast.makeText(this@FoodPrepOverlayService, "Snoozed: Popup in 10 minutes", Toast.LENGTH_SHORT).show()
                removeFloatingView()
                stopSelf()
            }
        }

        // Skip Button (won't popup again today)
        val skipBtn = Button(this).apply {
            text = "Skip\nToday"
            textSize = 11f
            setTextColor(Color.parseColor("#D4D4D8"))
            val bg = GradientDrawable().apply {
                setColor(Color.parseColor("#1E1E26"))
                cornerRadius = 12 * density
                setStroke((1 * density).toInt(), Color.parseColor("#323240"))
            }
            background = bg
            layoutParams = LinearLayout.LayoutParams(0, (46 * density).toInt(), 1.0f).apply {
                marginEnd = (6 * density).toInt()
            }
            setOnClickListener {
                handleSkipToday(this@FoodPrepOverlayService)
                Toast.makeText(this@FoodPrepOverlayService, "Skipped for today", Toast.LENGTH_SHORT).show()
                removeFloatingView()
                stopSelf()
            }
        }

        // Done Button with Teal gradient
        val doneBtn = Button(this).apply {
            text = "Done"
            textSize = 12.5f
            setTextColor(Color.WHITE)
            paint.isFakeBoldText = true
            val bg = GradientDrawable().apply {
                colors = intArrayOf(Color.parseColor("#00C9A7"), Color.parseColor("#00B4D8"))
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
                cornerRadius = 12 * density
            }
            background = bg
            layoutParams = LinearLayout.LayoutParams(0, (46 * density).toInt(), 1.1f)
            setOnClickListener {
                Toast.makeText(this@FoodPrepOverlayService, "Preparation saved!", Toast.LENGTH_SHORT).show()
                removeFloatingView()
                stopSelf()
            }
        }

        buttonRow.addView(tempSkipBtn)
        buttonRow.addView(skipBtn)
        buttonRow.addView(doneBtn)
        rootCard.addView(buttonRow)

        floatingView = rootCard

        try {
            windowManager?.addView(floatingView, params)
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    private fun removeFloatingView() {
        floatingView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
            floatingView = null
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onDestroy() {
        removeFloatingView()
        super.onDestroy()
    }

    private fun loadTomorrowFoods(jsonStr: String?, tomorrowCal: Calendar): List<FoodItemModel> {
        val result = mutableListOf<FoodItemModel>()

        // 1. If JSON was passed in Intent extra, parse it
        if (!jsonStr.isNullOrEmpty()) {
            try {
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    result.add(
                        FoodItemModel(
                            id = obj.optString("id"),
                            name = obj.optString("name"),
                            count = obj.optString("count"),
                            notes = obj.optString("notes"),
                            deadline = obj.optString("deadline"),
                            mealType = obj.optString("mealType")
                        )
                    )
                }
                return result
            } catch (_: Exception) {}
        }

        // 2. Otherwise read from foods_data.json
        try {
            val candidates = listOf(
                File(filesDir.parentFile, "app_flutter/foods_data.json"),
                File(filesDir, "foods_data.json"),
                File(filesDir, "app_flutter/foods_data.json")
            )
            var targetFile: File? = null
            for (f in candidates) {
                if (f.exists() && f.length() > 0) {
                    targetFile = f
                    break
                }
            }

            if (targetFile != null) {
                val array = JSONArray(targetFile.readText())
                val dayOfWeek = tomorrowCal.get(Calendar.DAY_OF_WEEK) // 1=Sun, 2=Mon...
                // In Dart: 1=Mon .. 7=Sun
                val dartWeekday = if (dayOfWeek == Calendar.SUNDAY) 7 else dayOfWeek - 1

                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val isEnabled = obj.optBoolean("isEnabled", true)
                    if (!isEnabled) continue

                    val daysArray = obj.optJSONArray("daysOfWeek")
                    var matchesDay = false
                    if (daysArray != null) {
                        for (d in 0 until daysArray.length()) {
                            if (daysArray.getInt(d) == dartWeekday) {
                                matchesDay = true
                                break
                            }
                        }
                    }

                    if (matchesDay) {
                        result.add(
                            FoodItemModel(
                                id = obj.optString("id"),
                                name = obj.optString("name"),
                                count = obj.optString("count"),
                                notes = obj.optString("notes"),
                                deadline = obj.optString("deadline", "09:00 AM"),
                                mealType = obj.optString("mealType").replaceFirstChar { it.uppercase() }
                            )
                        )
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return result
    }

    private fun isFoodChecked(prefs: android.content.SharedPreferences, foodId: String): Boolean {
        val set = prefs.getStringSet("flutter.food_prep_checked_ids", emptySet()) ?: emptySet()
        return set.contains(foodId)
    }

    private fun setFoodChecked(prefs: android.content.SharedPreferences, foodId: String, checked: Boolean) {
        val set = prefs.getStringSet("flutter.food_prep_checked_ids", emptySet())?.toMutableSet() ?: mutableSetOf()
        if (checked) {
            set.add(foodId)
        } else {
            set.remove(foodId)
        }
        prefs.edit().putStringSet("flutter.food_prep_checked_ids", set).apply()
    }

    companion object {
        const val ACTION_SHOW = "com.example.lnote.ACTION_SHOW_FOOD_PREP"
        const val ACTION_CLOSE = "com.example.lnote.ACTION_CLOSE_FOOD_PREP"
        const val EXTRA_ITEMS_JSON = "items_json"

        fun handleTempSkip(context: Context) {
            // Schedule Alarm in 10 minutes
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, FoodPrepAlarmReceiver::class.java).apply {
                action = FoodPrepAlarmReceiver.ACTION_ALARM_TRIGGER
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                901,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val triggerTime = System.currentTimeMillis() + 10 * 60 * 1000 // 10 minutes
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
            }
        }

        fun handleSkipToday(context: Context) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            prefs.edit().putString("flutter.food_prep_last_skipped_date", todayStr).apply()
        }
    }
}

data class FoodItemModel(
    val id: String,
    val name: String,
    val count: String,
    val notes: String,
    val deadline: String,
    val mealType: String
)
