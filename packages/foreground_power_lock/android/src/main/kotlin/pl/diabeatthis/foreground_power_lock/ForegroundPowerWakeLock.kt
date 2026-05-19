package pl.diabeatthis.foreground_power_lock

import android.content.Context
import android.os.PowerManager
import android.util.Log

object ForegroundPowerWakeLock {
    private const val DEFAULT_TIMEOUT_MS = 5_000L
    private const val MAX_TIMEOUT_MS = 30_000L

    private val wakeLocks = mutableMapOf<String, PowerManager.WakeLock>()

    @Synchronized
    fun acquire(
        context: Context,
        wakeLockTag: String,
        logTag: String,
        timeoutMillis: Long? = null,
        maxTimeoutMillis: Long = MAX_TIMEOUT_MS,
    ) {
        val timeout = (timeoutMillis ?: DEFAULT_TIMEOUT_MS)
            .coerceIn(1_000L, maxTimeoutMillis)
        releaseLocked(wakeLockTag, logTag)

        val powerManager = context.applicationContext
            .getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            wakeLockTag,
        )
        lock.setReferenceCounted(false)
        lock.acquire(timeout)
        wakeLocks[wakeLockTag] = lock

        Log.i(logTag, "PARTIAL_WAKE_LOCK acquired for ${timeout}ms")
    }

    @Synchronized
    fun release(wakeLockTag: String, logTag: String) {
        releaseLocked(wakeLockTag, logTag)
    }

    private fun releaseLocked(wakeLockTag: String, logTag: String) {
        val lock = wakeLocks.remove(wakeLockTag) ?: return
        try {
            if (lock.isHeld) {
                lock.release()
                Log.i(logTag, "PARTIAL_WAKE_LOCK released")
            }
        } catch (e: RuntimeException) {
            Log.w(logTag, "Failed to release PARTIAL_WAKE_LOCK", e)
        }
    }
}
