package com.example.lnote

import android.app.ActivityManager
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.content.res.Configuration
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
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

/**
 * WindowManager-based full-screen conscious blocker overlay.
 *
 * Guarantees display over restricted applications on all Android devices (including OnePlus,
 * OPPO, Xiaomi, and Samsung) where background activity launches (BAL) are blocked by OEM security.
 * Uses TYPE_APPLICATION_OVERLAY backed by the user-granted SYSTEM_ALERT_WINDOW permission.
 */
object AppUsageBlockerOverlayManager {

    data class BlockerPalette(
        val isDark: Boolean,
        val bg: Int,
        val titleText: Int,
        val subtitleText: Int,
        val sectionLabel: Int,
        val badgeText: Int,
        val badgeBg: Int,
        val badgeStroke: Int,
        val inputLabel: Int,
        val inputBg: Int,
        val inputStroke: Int,
        val inputText: Int,
        val inputHint: Int,
        val chipUnselectedBg: Int,
        val chipUnselectedStroke: Int,
        val chipUnselectedText: Int,
        val chipSelectedBg: Int,
        val chipSelectedStroke: Int,
        val chipSelectedText: Int,
        val leaveBtnBg: Int,
        val leaveBtnStroke: Int,
        val leaveBtnText: Int,
        val continueBtnDisabledBg: Int,
        val continueBtnDisabledText: Int,
        val continueBtnActiveStart: Int,
        val continueBtnActiveEnd: Int,
        val continueBtnActiveText: Int
    )

    fun isSystemInDarkMode(context: Context): Boolean {
        // 1. Check system-level Resources (reflects actual OS setting)
        val sysConfig = android.content.res.Resources.getSystem().configuration
        val sysNightMode = sysConfig.uiMode and Configuration.UI_MODE_NIGHT_MASK
        if (sysNightMode == Configuration.UI_MODE_NIGHT_YES) return true
        if (sysNightMode == Configuration.UI_MODE_NIGHT_NO) return false

        // 2. Check context resources
        val ctxNightMode = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK
        if (ctxNightMode == Configuration.UI_MODE_NIGHT_YES) return true
        if (ctxNightMode == Configuration.UI_MODE_NIGHT_NO) return false

        // 3. Check UiModeManager
        val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as? android.app.UiModeManager
        if (uiModeManager != null) {
            if (uiModeManager.nightMode == android.app.UiModeManager.MODE_NIGHT_YES) return true
            if (uiModeManager.nightMode == android.app.UiModeManager.MODE_NIGHT_NO) return false
        }

        return false
    }

    fun getBlockerPalette(context: Context): BlockerPalette {
        val isDark = isSystemInDarkMode(context)
        AppUsageDiagnosticLogger.i("Blocker theme evaluated: isDark=$isDark")
        return if (isDark) {
            BlockerPalette(
                isDark = true,
                bg = Color.parseColor("#0D0D11"),
                titleText = Color.WHITE,
                subtitleText = Color.parseColor("#9E9EA8"),
                sectionLabel = Color.parseColor("#80FFFFFF"),
                badgeText = Color.parseColor("#00C9A7"),
                badgeBg = Color.parseColor("#1500C9A7"),
                badgeStroke = Color.parseColor("#3300C9A7"),
                inputLabel = Color.parseColor("#00C9A7"),
                inputBg = Color.parseColor("#181820"),
                inputStroke = Color.parseColor("#2C2C3A"),
                inputText = Color.WHITE,
                inputHint = Color.parseColor("#666675"),
                chipUnselectedBg = Color.parseColor("#1C1C24"),
                chipUnselectedStroke = Color.parseColor("#2E2E3C"),
                chipUnselectedText = Color.parseColor("#CCCCCC"),
                chipSelectedBg = Color.parseColor("#2A00C9A7"),
                chipSelectedStroke = Color.parseColor("#00C9A7"),
                chipSelectedText = Color.parseColor("#00C9A7"),
                leaveBtnBg = Color.parseColor("#1C1C24"),
                leaveBtnStroke = Color.parseColor("#323242"),
                leaveBtnText = Color.parseColor("#E0E0E6"),
                continueBtnDisabledBg = Color.parseColor("#1E1E26"),
                continueBtnDisabledText = Color.parseColor("#555566"),
                continueBtnActiveStart = Color.parseColor("#00C9A7"),
                continueBtnActiveEnd = Color.parseColor("#00D4FF"),
                continueBtnActiveText = Color.WHITE
            )
        } else {
            BlockerPalette(
                isDark = false,
                bg = Color.parseColor("#F5F5F7"),
                titleText = Color.parseColor("#1A1A1F"),
                subtitleText = Color.parseColor("#666675"),
                sectionLabel = Color.parseColor("#7A7A88"),
                badgeText = Color.parseColor("#008C73"),
                badgeBg = Color.parseColor("#1800C9A7"),
                badgeStroke = Color.parseColor("#4400C9A7"),
                inputLabel = Color.parseColor("#008C73"),
                inputBg = Color.parseColor("#FFFFFF"),
                inputStroke = Color.parseColor("#DCDCE5"),
                inputText = Color.parseColor("#1A1A1F"),
                inputHint = Color.parseColor("#9E9EA8"),
                chipUnselectedBg = Color.parseColor("#FFFFFF"),
                chipUnselectedStroke = Color.parseColor("#D5D5E0"),
                chipUnselectedText = Color.parseColor("#444452"),
                chipSelectedBg = Color.parseColor("#E0F7F2"),
                chipSelectedStroke = Color.parseColor("#00A88A"),
                chipSelectedText = Color.parseColor("#008C73"),
                leaveBtnBg = Color.parseColor("#EAEAEF"),
                leaveBtnStroke = Color.parseColor("#D0D0DC"),
                leaveBtnText = Color.parseColor("#2D2D38"),
                continueBtnDisabledBg = Color.parseColor("#E0E0E8"),
                continueBtnDisabledText = Color.parseColor("#A0A0B0"),
                continueBtnActiveStart = Color.parseColor("#00C9A7"),
                continueBtnActiveEnd = Color.parseColor("#009FBD"),
                continueBtnActiveText = Color.WHITE
            )
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var activeOverlayView: View? = null
    private var activePackageName: String? = null
    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null

    fun isShowing(): Boolean = activeOverlayView != null

    fun isShowingFor(packageName: String): Boolean =
        activeOverlayView != null && activePackageName == packageName

    fun dismiss() {
        mainHandler.post {
            removeOverlayInternal()
        }
    }

    fun show(context: Context, packageName: String, mode: String = "normal") {
        mainHandler.post {
            try {
                if (isShowingFor(packageName)) {
                    return@post
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                    AppUsageDiagnosticLogger.w("Cannot show blocker overlay: SYSTEM_ALERT_WINDOW not granted")
                    return@post
                }

                removeOverlayInternal()

                val wm = context.getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return@post
                windowManager = wm

                val isDark = isSystemInDarkMode(context)
                val themeRes = if (isDark) {
                    android.R.style.Theme_DeviceDefault_NoActionBar
                } else {
                    android.R.style.Theme_DeviceDefault_Light_NoActionBar
                }
                val themedContext = ContextThemeWrapper(context, themeRes)
                val overlayView = buildBlockerView(themedContext, packageName, mode)
                val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    layoutType,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.FILL
                    x = 0
                    y = 0
                    softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
                }

                wm.addView(overlayView, params)
                activeOverlayView = overlayView
                activePackageName = packageName

                requestAudioFocusToPauseMedia(context)
                AppUsageDiagnosticLogger.i("Conscious blocker WindowManager overlay displayed for [$packageName]")
            } catch (e: Exception) {
                AppUsageDiagnosticLogger.e("Failed to display WindowManager overlay for $packageName", e)
            }
        }
    }

    private fun removeOverlayInternal() {
        try {
            activeOverlayView?.let {
                windowManager?.removeView(it)
            }
        } catch (e: Exception) {
            // Ignore if already removed
        }
        activeOverlayView = null
        activePackageName = null
        abandonAudioFocus()
    }

    private fun buildBlockerView(context: Context, targetPackage: String, targetMode: String): View {
        val density = context.resources.displayMetrics.density
        val isStrict = targetMode.equals("strict", ignoreCase = true)
        val pm = context.packageManager
        val palette = getBlockerPalette(context)

        val targetAppName = try {
            val appInfo = pm.getApplicationInfo(targetPackage, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            targetPackage.substringAfterLast('.')
        }

        val prefs = context.getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
        val limitMinutes = prefs.getInt("daily_limit_$targetPackage", 30)
        val appUsageMonitor: AppUsageMonitor = AppUsageMonitorImpl(context)
        val usedMs = appUsageMonitor.getDailyUsage(targetPackage)
        val usedMinutes = (usedMs / 60000).toInt()

        var selectedDurationMinutes = 1
        var selectedCategory = "other"

        // Root container that captures back button presses and adapts system status bar
        val rootLayout = object : FrameLayout(context) {
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                if (event.keyCode == KeyEvent.KEYCODE_BACK && event.action == KeyEvent.ACTION_UP) {
                    handleLeaveApp(context, targetPackage)
                    return true
                }
                return super.dispatchKeyEvent(event)
            }
        }.apply {
            setBackgroundColor(palette.bg)
            isFocusable = true
            isFocusableInTouchMode = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                var flags = systemUiVisibility
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
                systemUiVisibility = flags
            }
        }

        val scroll = ScrollView(context).apply {
            isFillViewport = true
            overScrollMode = View.OVER_SCROLL_IF_CONTENT_SCROLLS
        }
        rootLayout.addView(
            scroll,
            FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT)
        )

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding((24 * density).toInt(), (40 * density).toInt(), (24 * density).toInt(), (32 * density).toInt())
        }
        scroll.addView(container)

        // Top Status Badge
        val topBadge = TextView(context).apply {
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
        val iconView = ImageView(context).apply {
            try {
                val appIcon = pm.getApplicationIcon(targetPackage)
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
        val questionView = TextView(context).apply {
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
        val subtitleView = TextView(context).apply {
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
        val catLabel = TextView(context).apply {
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
        val catScroll = HorizontalScrollView(context).apply {
            overScrollMode = View.OVER_SCROLL_NEVER
            isHorizontalScrollBarEnabled = false
        }
        val catContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        catScroll.addView(catContainer)

        val categories = listOf("Work", "Study", "Communication", "Research", "Other")
        val categoryButtons = mutableListOf<Button>()

        for (cat in categories) {
            val isInitial = cat.lowercase() == selectedCategory
            val btn = Button(context).apply {
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
        val inputLabel = TextView(context).apply {
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

        // Text Input Field
        val reasonInput = EditText(context).apply {
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
        val durationLabel = TextView(context).apply {
            text = "SESSION DURATION LIMIT"
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
        container.addView(durationLabel, durLabelParams)

        // Duration Chips
        val durScroll = HorizontalScrollView(context).apply {
            overScrollMode = View.OVER_SCROLL_NEVER
            isHorizontalScrollBarEnabled = false
        }
        val durContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        durScroll.addView(durContainer)

        val durationPresets = listOf(1, 2, 5, 10, 15, 30)
        val durationButtons = mutableListOf<Button>()

        fun updateDurationStyles(activeDur: Int) {
            for (b in durationButtons) {
                val isCurr = b.text.toString() == "${activeDur}m" || (b.tag == "custom" && activeDur !in durationPresets)
                b.setTextColor(if (isCurr) palette.chipSelectedText else palette.chipUnselectedText)
                val bg = GradientDrawable().apply {
                    cornerRadius = 10 * density
                    setColor(if (isCurr) palette.chipSelectedBg else palette.chipUnselectedBg)
                    setStroke((1 * density).toInt(), if (isCurr) palette.chipSelectedStroke else palette.chipUnselectedStroke)
                }
                b.background = bg
            }
        }

        for (dur in durationPresets) {
            val isInitial = dur == selectedDurationMinutes
            val btn = Button(context).apply {
                text = "${dur}m"
                textSize = 12f
                isAllCaps = false
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
            val btnParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, (36 * density).toInt()).apply {
                marginEnd = (6 * density).toInt()
            }
            durContainer.addView(btn, btnParams)
        }

        // Custom duration chip
        val customBtn = Button(context).apply {
            tag = "custom"
            text = "Custom"
            textSize = 12f
            isAllCaps = false
            setTextColor(palette.chipUnselectedText)
            val bBg = GradientDrawable().apply {
                cornerRadius = 10 * density
                setColor(palette.chipUnselectedBg)
                setStroke((1 * density).toInt(), palette.chipUnselectedStroke)
            }
            background = bBg
            setOnClickListener {
                showCustomDurationDialog(context, palette) { customMins ->
                    selectedDurationMinutes = customMins
                    text = "${customMins}m"
                    updateDurationStyles(customMins)
                }
            }
        }
        durationButtons.add(customBtn)
        val customParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, (36 * density).toInt())
        durContainer.addView(customBtn, customParams)

        val durScrollParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            bottomMargin = (24 * density).toInt()
        }
        container.addView(durScroll, durScrollParams)

        // Action Buttons Row
        val buttonRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
        }

        val leaveBtn = Button(context).apply {
            text = "Leave App"
            setTextColor(palette.leaveBtnText)
            textSize = 13.5f
            isAllCaps = false
            val leaveBg = GradientDrawable().apply {
                cornerRadius = 14 * density
                setColor(palette.leaveBtnBg)
                setStroke((1 * density).toInt(), palette.leaveBtnStroke)
            }
            background = leaveBg
            setOnClickListener {
                handleLeaveApp(context, targetPackage)
            }
        }
        val leaveParams = LinearLayout.LayoutParams(0, (48 * density).toInt(), 1f).apply {
            marginEnd = (10 * density).toInt()
        }
        buttonRow.addView(leaveBtn, leaveParams)

        val continueBtn = Button(context).apply {
            text = "Continue"
            setTextColor(palette.continueBtnDisabledText)
            textSize = 14f
            paint.isFakeBoldText = true
            isAllCaps = false
            isEnabled = false
            val disabledBg = GradientDrawable().apply {
                cornerRadius = 14 * density
                setColor(palette.continueBtnDisabledBg)
            }
            background = disabledBg
            setOnClickListener {
                val typedReason = reasonInput.text.toString().trim()
                if (typedReason.length >= 3) {
                    handleContinue(context, targetPackage, targetAppName, targetMode, typedReason, selectedCategory, selectedDurationMinutes)
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

        return rootLayout
    }

    private fun showCustomDurationDialog(context: Context, palette: BlockerPalette, onSelected: (Int) -> Unit) {
        val input = EditText(context).apply {
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

        // Overlay dialog with TYPE_APPLICATION_OVERLAY
        val dialog = AlertDialog.Builder(context, dialogTheme)
            .setTitle("Custom Duration")
            .setMessage("How many minutes do you need for this session?")
            .setView(input)
            .setPositiveButton("Set") { _, _ ->
                val mins = input.text.toString().toIntOrNull() ?: 5
                val clamped = mins.coerceIn(1, 120)
                onSelected(clamped)
            }
            .setNegativeButton("Cancel", null)
            .create()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            dialog.window?.setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
        }
        dialog.show()
    }

    private fun handleLeaveApp(context: Context, targetPackage: String) {
        try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            am?.killBackgroundProcesses(targetPackage)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(homeIntent)
        dismiss()
    }

    private fun handleContinue(
        context: Context,
        targetPackage: String,
        targetAppName: String,
        targetMode: String,
        typedReason: String,
        selectedCategory: String,
        durationMinutes: Int
    ) {
        val durationMs = durationMinutes * 60 * 1000L
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val prefs = context.getSharedPreferences("lnote_app_usage_prefs", Context.MODE_PRIVATE)
        val expiresAt = System.currentTimeMillis() + durationMs

        prefs.edit()
            .putLong("temp_remaining_ms_$targetPackage", durationMs)
            .putString("temp_remaining_date_$targetPackage", todayStr)
            .putLong("temp_access_$targetPackage", expiresAt)
            .commit()

        AppUsageDiagnosticLogger.i("Conscious unlock granted for [$targetPackage]: ${durationMinutes}m, reason='$typedReason', category='$selectedCategory'")

        // Schedule session expiration alarm
        AppUsageAlarmReceiver.scheduleSessionExpireAlarm(context, targetPackage, targetAppName, expiresAt)

        // Save conscious reason record locally
        saveInterventionRecord(context, targetPackage, targetAppName, typedReason, durationMinutes, targetMode, selectedCategory)

        // Remove overlay so user can use the target app freely
        dismiss()
    }

    private fun saveInterventionRecord(
        context: Context,
        packageName: String,
        appName: String,
        reason: String,
        durationMins: Int,
        mode: String,
        category: String
    ) {
        try {
            val now = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            val file = File(context.filesDir, "usage_reasons.json")
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

    private fun requestAudioFocusToPauseMedia(context: Context) {
        try {
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
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

    private fun abandonAudioFocus() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            } else {
                @Suppress("DEPRECATION")
                audioManager?.abandonAudioFocus(null)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
