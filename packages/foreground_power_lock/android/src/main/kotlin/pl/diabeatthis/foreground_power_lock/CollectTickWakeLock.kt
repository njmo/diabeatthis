package pl.diabeatthis.foreground_power_lock

import android.content.Context
import android.os.PowerManager
import android.util.Log

internal object CollectTickWakeLock {
    private const val TAG = "CollectTickWakeLock"
    private const val WAKE_LOCK_TAG = "diabeatthis:collect_tick"
    private const val DEFAULT_TIMEOUT_MS = 5_000L
    private const val MAX_TIMEOUT_MS = 30_000L

    private var wakeLock: PowerManager.WakeLock? = null

    @Synchronized
    fun acquire(context: Context, timeoutMillis: Long?) {
        val timeout = (timeoutMillis ?: DEFAULT_TIMEOUT_MS)
            .coerceIn(1_000L, MAX_TIMEOUT_MS)
        releaseLocked()

        val powerManager = context.applicationContext
            .getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            WAKE_LOCK_TAG,
        )
        lock.setReferenceCounted(false)
        lock.acquire(timeout)
        wakeLock = lock

        Log.i(TAG, "PARTIAL_WAKE_LOCK acquired for ${timeout}ms")
    }

    @Synchronized
    fun release() {
        releaseLocked()
    }

    private fun releaseLocked() {
        val lock = wakeLock ?: return
        try {
            if (lock.isHeld) {
                lock.release()
                Log.i(TAG, "PARTIAL_WAKE_LOCK released")
            }
        } catch (e: RuntimeException) {
            Log.w(TAG, "Failed to release PARTIAL_WAKE_LOCK", e)
        } finally {
            wakeLock = null
        }
    }
}
