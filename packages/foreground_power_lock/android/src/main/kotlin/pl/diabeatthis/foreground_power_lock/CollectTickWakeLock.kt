package pl.diabeatthis.foreground_power_lock

import android.content.Context

internal object CollectTickWakeLock {
    private const val TAG = "CollectTickWakeLock"
    private const val WAKE_LOCK_TAG = "diabeatthis:collect_tick"
    private const val MAX_TIMEOUT_MS = 30_000L

    fun acquire(context: Context, timeoutMillis: Long?) {
        ForegroundPowerWakeLock.acquire(
            context = context,
            wakeLockTag = WAKE_LOCK_TAG,
            logTag = TAG,
            timeoutMillis = timeoutMillis,
            maxTimeoutMillis = MAX_TIMEOUT_MS,
        )
    }

    fun release() {
        ForegroundPowerWakeLock.release(WAKE_LOCK_TAG, TAG)
    }
}
