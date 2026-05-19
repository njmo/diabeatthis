package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.pravera.flutter_foreground_task.service.ForegroundService
import org.json.JSONObject
import kotlin.math.roundToInt

class AapsGlucoseReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_NEW_SGV) return

        val sgvJson = intent.getStringExtra(EXTRA_SGV) ?: return
        val data = try {
            JSONObject(sgvJson)
        } catch (_: Exception) {
            return
        }

        val timestamp = data.optLong("date", 0L)
        val sgv = data.optDouble("sgv", Double.NaN)
        if (timestamp <= 0L || sgv.isNaN() || sgv <= 0.0) return

        val externalId = data.optString("_id").ifBlank { "aaps-$timestamp" }
        val direction = data.optString("direction").ifBlank { "Flat" }
        val glucosePayload = JSONObject()
            .put("externalId", externalId)
            .put("source", "aaps")
            .put("timestamp", timestamp)
            .put("sgv", sgv.roundToInt())
            .put("direction", direction)

        val eventPayload = JSONObject()
            .put("external_event", "native_receiver")
            .put(
                "data",
                JSONObject()
                    .put("kind", "glucose")
                    .put("data", glucosePayload),
            )

        NativeReceiverWakeLock.acquire(context)
        ForegroundService.sendData(eventPayload.toString())
    }

    companion object {
        fun setEnabled(context: Context) {
            setEnabledState(context, true)
        }

        fun setDisabled(context: Context) {
            setEnabledState(context, false)
        }

        private fun setEnabledState(context: Context, enabled: Boolean) {
            setReceiverEnabledState(context, AapsGlucoseReceiver::class.java, enabled)
        }

        const val ACTION_NEW_SGV = "info.nightscout.client.NEW_SGV"
        const val EXTRA_SGV = "sgv"
    }
}
