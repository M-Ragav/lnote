package com.example.lnote

import android.util.Log

/**
 * Diagnostic logger for LNote App Usage Monitoring & Restriction Engine.
 *
 * Provides structured, filterable logs under the tag 'LNoteUsageMonitor'.
 * Privacy Guarantee: Strictly logs metadata (package names, modes, timestamps, durations).
 * NEVER logs screen text content, keystrokes, user typing, or personal data.
 */
object AppUsageDiagnosticLogger {
    private const val TAG = "LNoteUsageMonitor"

    fun d(message: String) {
        Log.d(TAG, message)
    }

    fun i(message: String) {
        Log.i(TAG, message)
    }

    fun w(message: String) {
        Log.w(TAG, message)
    }

    fun e(message: String, throwable: Throwable? = null) {
        if (throwable != null) {
            Log.e(TAG, message, throwable)
        } else {
            Log.e(TAG, message)
        }
    }

    fun logMonitorStarted(componentName: String) {
        i("==================================================")
        i("Usage Monitor ACTIVE: $componentName")
        i("Monitoring app foreground transitions via UsageStatsManager...")
        i("==================================================")
    }

    fun logMonitorStopped(componentName: String) {
        w("Usage Monitor STOPPED: $componentName")
    }

    fun logEventReceived(packageName: String?, className: String?, eventType: Int) {
        d("Event received: type=$eventType, pkg=$packageName, class=$className")
    }

    fun logEventIgnored(packageName: String?, reason: String) {
        d("Event ignored [$packageName]: $reason")
    }

    fun logRestrictionDecision(
        packageName: String,
        mode: String,
        isControlled: Boolean,
        decision: String,
        details: String
    ) {
        i("Policy Decision [$packageName]: Controlled=$isControlled, Mode=$mode, Decision=$decision ($details)")
    }

    fun logBlockerLaunched(packageName: String, mode: String) {
        i(">>> Launching Conscious Blocker UI for [$packageName] in mode: $mode")
    }

    fun logBlockerSuppressed(packageName: String, reason: String) {
        d("Blocker launch suppressed for [$packageName]: $reason")
    }

    fun logSessionUpdate(packageName: String, action: String, remainingMs: Long) {
        i("Session Tracker [$packageName]: action=$action, remainingMs=$remainingMs (${remainingMs / 1000}s)")
    }
}
