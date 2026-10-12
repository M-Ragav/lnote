package com.example.lnote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class FoodPrepBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean("flutter.food_prep_enabled", true)
            if (isEnabled) {
                FoodPrepAlarmReceiver.scheduleNextDailyAlarm(context)
            }
        }
    }
}
