package com.example.lnote

import android.app.Activity
import android.app.ActivityManager
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class AppUsageBlockerActivity : Activity() {

    private lateinit var targetPackage: String
    private var targetAppName: String = "App"
    private var targetMode: String = "normal"
    private var selectedDurationMinutes = 1
    private var selectedCategory: String = "other"
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    companion object {
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        const val EXTRA_APP_NAME = "extra_app_name"
        const val EXTRA_MODE = "extra_mode"

        @Volatile
        private var activePackageName: String? = null
        @Volatile
        private var isVisible: Boolean = false

        fun isShowingFor(packageName: String): Boolean {
            return isVisible && activePackageName == packageName
        }

        fun isAnyBlockerVisible(): Boolean {
            return isVisible
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        targetPackage = intent.getStringExtra(EXTRA_PACKAGE_NAME) ?: run {
            finish()
            return
        }
        targetMode = intent.getStringExtra(EXTRA_MODE) ?: "normal"

        targetAppName = intent.getStringExtra(EXTRA_APP_NAME) ?: run {
            try {
                val appInfo = packageManager.getApplicationInfo(targetPackage, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                targetPackage.substringAfterLast('.')
            }
        }

        activePackageName = targetPackage
        isVisible = true

        val palette = AppUsageBlockerOverlayManager.getBlockerPalette(this)
        window.setBackgroundDrawable(ColorDrawable(palette.bg))
        window.statusBarColor = palette.bg
        window.navigationBarColor = palette.bg

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            var flags = window.decorView.systemUiVisibility
            flags = if (palette.isDark) {
                flags and View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
            } else {
                flags or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                flags = if (palette.isDark) {
                    flags and View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR.inv()
                } else {
                    flags or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                }
            }
            window.decorView.systemUiVisibility = flags
        }

        // Mute any ongoing media / video audio from target app immediately
        requestAudioFocusToPauseMedia()

        // Build Full Screen UI
        buildUi()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        val newPkg = intent?.getStringExtra(EXTRA_PACKAGE_NAME) ?: return
        val newMode = intent.getStringExtra(EXTRA_MODE) ?: "normal"
        if (newPkg != targetPackage || newMode != targetMode) {
            targetPackage = newPkg
            targetMode = newMode
            targetAppName = intent.getStringExtra(EXTRA_APP_NAME) ?: run {
                try {
                    val appInfo = packageManager.getApplicationInfo(targetPackage, 0)
                    packageManager.getApplicationLabel(appInfo).toString()
                } catch (e: Exception) {
                    targetPackage.substringAfterLast('.')
                }
            }
            activePackageName = targetPackage
            buildUi()
        }
    }

    override fun onResume() {
        super.onResume()
        isVisible = true
        activePackageName = targetPackage
        requestAudioFocusToPauseMedia()
    }

    override fun onPause() {
        super.onPause()
        isVisible = false
    }

    override fun onDestroy() {
        super.onDestroy()
        if (activePackageName == targetPackage) {
            activePackageName = null
        }
        isVisible = false
    }

    private fun requestAudioFocusToPauseMedia() {
        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
                audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attrs)
                    .build()
                audioFocusRequest?.let { audioManager?.requestAudioFocus(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun buildUi() {
        val palette = AppUsageBlockerOverlayManager.getBlockerPalette(this)
        val density = resources.displayMetrics.density
        val isStrict = targetMode.equals("strict", ignoreCase = true)

        val prefs = getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
        val limitMinutes = prefs.getInt("daily_limit_$targetPackage", 30)
        val appUsageMonitor: AppUsageMonitor = AppUsageMonitorImpl(this)
        val usedMs = appUsageMonitor.getDailyUsage(targetPackage)
        val usedMinutes = (usedMs / 60000).toInt()

        val scroll = ScrollView(this).apply {
            setBackgroundColor(palette.bg)
            isFillViewport = true
        }

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding((24 * density).toInt(), (36 * density).toInt(), (24 * density).toInt(), (32 * density).toInt())
        }
        scroll.addView(container)

        // Top Status Badge
        val topBadge = TextView(this).apply {
            text = if (isStrict) {
                "🛡️ Strict Mode Active"
            } else {
                "⏱️ Daily Limit: $usedMinutes / $limitMinutes min"
            }
            setTextColor(palette.badgeText)
            textSize = 12.5f
            paint.isFakeBoldText = true
            val tagBg = GradientDrawable().apply {
                cornerRadius = 14 * density
                setColor(palette.badgeBg)
                setStroke((1 * density).toInt(), palette.badgeStroke)
            }
            background = tagBg
            setPadding((14 * density).toInt(), (7 * density).toInt(), (14 * density).toInt(), (7 * density).toInt())
        }
        val topBadgeParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = (14 * density).toInt()
        }
        container.addView(topBadge, topBadgeParams)

        // App Icon
        val iconView = ImageView(this).apply {
            try {
                val appIcon = packageManager.getApplicationIcon(targetPackage)
                setImageDrawable(appIcon)
            } catch (e: Exception) {
                setImageResource(R.mipmap.ic_launcher)
            }
        }
        val iconParams = LinearLayout.LayoutParams((56 * density).toInt(), (56 * density).toInt()).apply {
            bottomMargin = (12 * density).toInt()
        }
        container.addView(iconView, iconParams)

        // Question Title
        val questionView = TextView(this).apply {
            text = "Why are you opening\n$targetAppName?"
            setTextColor(palette.titleText)
            textSize = 21f
            gravity = Gravity.CENTER
            paint.isFakeBoldText = true
        }
        val questionParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = (6 * density).toInt()
        }
        container.addView(questionView, questionParams)

        // Subtitle instructions
        val subtitleView = TextView(this).apply {
            text = if (isStrict) {
                "Strict Mode requires an intentional reason and duration before each session.\n(Used today: ${usedMinutes}m)"
            } else {
                "Daily limit of $limitMinutes min reached (${usedMinutes}m used today).\nProvide a conscious intention to request extra time."
            }
            setTextColor(palette.subtitleText)
            textSize = 12f
            gravity = Gravity.CENTER
        }
        val subParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = (18 * density).toInt()
        }
        container.addView(subtitleView, subParams)

        // Reason Category Label
        val catLabel = TextView(this).apply {
            text = "INTENTION CATEGORY"
            setTextColor(palette.sectionLabel)
            textSize = 11f
            paint.isFakeBoldText = true
        }
        val catLabelParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = (8 * density).toInt()
        }
        container.addView(catLabel, catLabelParams)

        // Category chips row
        val catScroll = HorizontalScrollView(this).apply {
            overScrollMode = View.OVER_SCROLL_NEVER
            isHorizontalScrollBarEnabled = false
        }
        val catContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        catScroll.addView(catContainer)

        val categories = listOf("Work", "Study", "Communication", "Research", "Other")
        val categoryButtons = mutableListOf<Button>()

        for (cat in categories) {
            val isInitial = cat.lowercase() == selectedCategory
            val btn = Button(this).apply {
                text = cat
                textSize = 12f
                isAllCaps = false
                setPadding((12 * density).toInt(), 0, (12 * density).toInt(), 0)
                setTextColor(if (isInitial) palette.chipSelectedText else palette.chipUnselectedText)
                val bBg = GradientDrawable().apply {
                    cornerRadius = 10 * density
                    setColor(if (isInitial) palette.chipSelectedBg else palette.chipUnselectedBg)
                    setStroke((1 * density).toInt(), if (isInitial) palette.chipSelectedStroke else palette.chipUnselectedStroke)
                }
                background = bBg
                setOnClickListener {
                    selectedCategory = cat.lowercase()
                    for (b in categoryButtons) {
                        val isCurr = b.text.toString().equals(cat, ignoreCase = true)
                        b.setTextColor(if (isCurr) palette.chipSelectedText else palette.chipUnselectedText)
                        val bg = GradientDrawable().apply {
                            cornerRadius = 10 * density
                            setColor(if (isCurr) palette.chipSelectedBg else palette.chipUnselectedBg)
                            setStroke((1 * density).toInt(), if (isCurr) palette.chipSelectedStroke else palette.chipUnselectedStroke)
                        }
                        b.background = bg
                    }
                }
            }
            categoryButtons.add(btn)
            val btnParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, (36 * density).toInt()).apply {
                marginEnd = (6 * density).toInt()
            }
            catContainer.addView(btn, btnParams)
        }
        val catScrollParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            bottomMargin = (14 * density).toInt()
        }
        container.addView(catScroll, catScrollParams)

        // Input Label
        val inputLabel = TextView(this).apply {
            text = "EXPLAIN YOUR INTENTION (REQUIRED)"
            setTextColor(palette.inputLabel)
            textSize = 11f
            paint.isFakeBoldText = true
        }
        val inputLabelParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = (8 * density).toInt()
        }
        container.addView(inputLabel, inputLabelParams)

        // Text Input Field for typing reason manually
        val reasonInput = EditText(this).apply {
            hint = "Type why you need this app right now..."
            setHintTextColor(palette.inputHint)
            setTextColor(palette.inputText)
            textSize = 14f
            minLines = 3
            maxLines = 4
            gravity = Gravity.TOP or Gravity.START
            val inputBg = GradientDrawable().apply {
                cornerRadius = 14 * density
                setColor(palette.inputBg)
                setStroke((1.2 * density).toInt(), palette.inputStroke)
            }
            background = inputBg
            setPadding((14 * density).toInt(), (12 * density).toInt(), (14 * density).toInt(), (12 * density).toInt())
        }
        val inputFieldParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = (16 * density).toInt()
        }
        container.addView(reasonInput, inputFieldParams)

        // Duration Label
        val durLabel = TextView(this).apply {
            text = "HOW LONG DO YOU NEED?"
            setTextColor(palette.sectionLabel)
            textSize = 11f
            paint.isFakeBoldText = true
        }
        val durLabelParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            bottomMargin = (8 * density).toInt()
        }
        container.addView(durLabel, durLabelParams)

        // Duration chips container
        val durScroll = HorizontalScrollView(this).apply {
            overScrollMode = View.OVER_SCROLL_NEVER
            isHorizontalScrollBarEnabled = false
        }
        val durContainer = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        durScroll.addView(durContainer)

        val durations = listOf(1, 2, 5, 10, 15, 30)
        val durationButtons = mutableListOf<Button>()

        fun updateDurationStyles(activeDur: Int) {
            for (b in durationButtons) {
                val isCurr = b.text.toString() == "${activeDur}m" || (b.tag == "custom" && activeDur !in durations)
                b.setTextColor(if (isCurr) palette.chipSelectedText else palette.chipUnselectedText)
                val bg = GradientDrawable().apply {
                    cornerRadius = 10 * density
                    setColor(if (isCurr) palette.chipSelectedBg else palette.chipUnselectedBg)
                    setStroke((1 * density).toInt(), if (isCurr) palette.chipSelectedStroke else palette.chipUnselectedStroke)
                }
                b.background = bg
            }
        }

        for (dur in durations) {
            val isInitial = dur == selectedDurationMinutes
            val btn = Button(this).apply {
                text = "${dur}m"
                textSize = 12f
                isAllCaps = false
                minWidth = (48 * density).toInt()
                setPadding((10 * density).toInt(), 0, (10 * density).toInt(), 0)
                setTextColor(if (isInitial) palette.chipSelectedText else palette.chipUnselectedText)
                val bBg = GradientDrawable().apply {
                    cornerRadius = 10 * density
                    setColor(if (isInitial) palette.chipSelectedBg else palette.chipUnselectedBg)
                    setStroke((1 * density).toInt(), if (isInitial) palette.chipSelectedStroke else palette.chipUnselectedStroke)
                }
                background = bBg
                setOnClickListener {
                    selectedDurationMinutes = dur
                    updateDurationStyles(dur)
                }
            }
            durationButtons.add(btn)
            val btnParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, (38 * density).toInt()).apply {
                marginEnd = (6 * density).toInt()
            }
            durContainer.addView(btn, btnParams)
        }

        // Custom Duration Button
        val customBtn = Button(this).apply {
            tag = "custom"
            text = "Custom"
            textSize = 12f
            isAllCaps = false
            setPadding((12 * density).toInt(), 0, (12 * density).toInt(), 0)
            setTextColor(palette.chipUnselectedText)
            val bBg = GradientDrawable().apply {
                cornerRadius = 10 * density
                setColor(palette.chipUnselectedBg)
                setStroke((1 * density).toInt(), palette.chipUnselectedStroke)
            }
            background = bBg
            setOnClickListener {
                showCustomDurationDialog(palette) { customMins ->
                    selectedDurationMinutes = customMins
                    text = "${customMins}m"
                    updateDurationStyles(customMins)
                }
            }
        }
        durationButtons.add(customBtn)
        val customBtnParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, (38 * density).toInt())
        durContainer.addView(customBtn, customBtnParams)

        val durScrollParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            bottomMargin = (22 * density).toInt()
        }
        container.addView(durScroll, durScrollParams)

        // Action Buttons Row (Leave App vs Continue)
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        // Leave App Button
        val leaveBtn = Button(this).apply {
            text = "Leave App"
            textSize = 13.5f
            isAllCaps = false
            setTextColor(palette.leaveBtnText)
            val btnBg = GradientDrawable().apply {
                cornerRadius = 14 * density
                setColor(palette.leaveBtnBg)
                setStroke((1 * density).toInt(), palette.leaveBtnStroke)
            }
            background = btnBg
            setOnClickListener {
                handleLeaveApp()
            }
        }
        val leaveParams = LinearLayout.LayoutParams(0, (48 * density).toInt(), 1f).apply {
            marginEnd = (10 * density).toInt()
        }
        buttonRow.addView(leaveBtn, leaveParams)

        // Continue Button
        val continueBtn = Button(this).apply {
            text = "Continue"
            textSize = 14f
            paint.isFakeBoldText = true
            isAllCaps = false
            isEnabled = false
            setTextColor(palette.continueBtnDisabledText)
            val btnBg = GradientDrawable().apply {
                cornerRadius = 14 * density
                setColor(palette.continueBtnDisabledBg)
            }
            background = btnBg
            setOnClickListener {
                val typedReason = reasonInput.text.toString().trim()
                if (typedReason.length >= 3) {
                    handleContinue(typedReason)
                }
            }
        }
        val continueParams = LinearLayout.LayoutParams(0, (48 * density).toInt(), 1.3f)
        buttonRow.addView(continueBtn, continueParams)

        container.addView(buttonRow)

        // TextWatcher: Enable Continue button only when reason is typed
        reasonInput.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val hasValidReason = (s?.toString()?.trim()?.length ?: 0) >= 3
                continueBtn.isEnabled = hasValidReason
                if (hasValidReason) {
                    continueBtn.setTextColor(palette.continueBtnActiveText)
                    val activeBg = GradientDrawable().apply {
                        cornerRadius = 14 * density
                        colors = intArrayOf(palette.continueBtnActiveStart, palette.continueBtnActiveEnd)
                        orientation = GradientDrawable.Orientation.LEFT_RIGHT
                    }
                    continueBtn.background = activeBg
                } else {
                    continueBtn.setTextColor(palette.continueBtnDisabledText)
                    val disabledBg = GradientDrawable().apply {
                        cornerRadius = 14 * density
                        setColor(palette.continueBtnDisabledBg)
                    }
                    continueBtn.background = disabledBg
                }
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        setContentView(scroll)

        reasonInput.post {
            reasonInput.requestFocus()
            val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            imm?.showSoftInput(reasonInput, InputMethodManager.SHOW_IMPLICIT)
        }
    }

    private fun showCustomDurationDialog(palette: AppUsageBlockerOverlayManager.BlockerPalette, onSelected: (Int) -> Unit) {
        val input = EditText(this).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
            hint = "Minutes (1 - 120)"
            setTextColor(palette.inputText)
            setHintTextColor(palette.inputHint)
            setText("20")
            setSelection(text.length)
        }
        val dialogTheme = if (palette.isDark) {
            AlertDialog.THEME_DEVICE_DEFAULT_DARK
        } else {
            AlertDialog.THEME_DEVICE_DEFAULT_LIGHT
        }
        AlertDialog.Builder(this, dialogTheme)
            .setTitle("Custom Duration")
            .setMessage("How many minutes do you need for this session?")
            .setView(input)
            .setPositiveButton("Set") { _, _ ->
                val mins = input.text.toString().toIntOrNull() ?: 5
                val clamped = mins.coerceIn(1, 120)
                onSelected(clamped)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun handleLeaveApp() {
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            am?.killBackgroundProcesses(targetPackage)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finishAndRemoveTask()
    }

    private fun handleContinue(typedReason: String) {
        val durationMs = selectedDurationMinutes * 60 * 1000L
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val prefs = getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
        val expiresAt = System.currentTimeMillis() + durationMs

        prefs.edit()
            .putLong("temp_remaining_ms_$targetPackage", durationMs)
            .putString("temp_remaining_date_$targetPackage", todayStr)
            .putLong("temp_access_$targetPackage", expiresAt)
            .commit()

        AppUsageDiagnosticLogger.i("Conscious unlock granted for [$targetPackage]: ${selectedDurationMinutes}m, reason='$typedReason', category='$selectedCategory'")

        // Schedule session expiration alarm
        AppUsageAlarmReceiver.scheduleSessionExpireAlarm(this, targetPackage, targetAppName, expiresAt)

        // Save conscious reason record locally
        saveInterventionRecord(targetPackage, targetAppName, typedReason, selectedDurationMinutes, targetMode, selectedCategory)

        // Launch target app cleanly
        try {
            val launchIntent = packageManager.getLaunchIntentForPackage(targetPackage)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
            }
        } catch (e: Exception) {
            AppUsageDiagnosticLogger.e("Failed to launch target app $targetPackage after unlock", e)
        }

        finish()
    }

    private fun saveInterventionRecord(
        packageName: String,
        appName: String,
        reason: String,
        durationMins: Int,
        mode: String,
        category: String
    ) {
        try {
            val now = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            val file = File(filesDir, "usage_reasons.json")
            val reasonsArray = if (file.exists()) {
                val content = file.readText()
                if (content.isNotEmpty()) JSONArray(content) else JSONArray()
            } else {
                JSONArray()
            }

            val reasonObj = JSONObject().apply {
                put("id", "reas_${System.currentTimeMillis()}")
                put("sessionId", "sess_${System.currentTimeMillis()}")
                put("packageId", packageName)
                put("appName", appName)
                put("mode", mode)
                put("timestamp", now)
                put("category", category)
                put("customReason", reason)
                put("requestedMinutes", durationMins)
                put("approvedMinutes", durationMins)
                put("wasAllowed", true)
            }
            reasonsArray.put(reasonObj)
            file.writeText(reasonsArray.toString())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        handleLeaveApp()
    }
}
