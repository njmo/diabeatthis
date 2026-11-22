package com.example.diabeatthis.common.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import pl.diabeatthis.foreground_power_lock.ForegroundPowerWakeLock

/** Holds the CPU while FlutterFire dispatches a meal decision push to Dart. */
class MealDecisionPushWakeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RECEIVE_FCM ||
            intent.hasExtra("type") ||
            intent.getStringExtra("requestId")?.matches(REQUEST_ID) != true
        ) return
        if (context.getSystemService(PowerManager::class.java).isInteractive) return

        try {
            ForegroundPowerWakeLock.acquire(
                context = context,
                wakeLockTag = "diabeatthis:meal_decision_push",
                logTag = TAG,
                timeoutMillis = 5_000L,
            )
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not hold the CPU for a meal decision push", error)
        }
    }

    private companion object {
        const val RECEIVE_FCM = "com.google.android.c2dm.intent.RECEIVE"
        const val TAG = "MealDecisionPush"
        val REQUEST_ID = Regex("[A-Za-z0-9_-]{1,128}")
    }
}
