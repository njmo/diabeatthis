package com.example.diabeatthis

import android.content.Context
import pl.diabeatthis.foreground_power_lock.ForegroundPowerWakeLock

object NativeReceiverWakeLock {
    private const val TAG = "NativeReceiverWakeLock"
    private const val WAKE_LOCK_TAG = "diabeatthis:native_receiver"
    private const val DEFAULT_TIMEOUT_MS = 5_000L
    private const val MAX_TIMEOUT_MS = 10_000L

    fun acquire(context: Context) {
        ForegroundPowerWakeLock.acquire(
            context = context,
            wakeLockTag = WAKE_LOCK_TAG,
            logTag = TAG,
            timeoutMillis = DEFAULT_TIMEOUT_MS,
            maxTimeoutMillis = MAX_TIMEOUT_MS,
        )
    }
}
