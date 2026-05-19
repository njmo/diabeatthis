package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.pravera.flutter_foreground_task.service.ForegroundService
import org.json.JSONObject
import kotlin.math.roundToInt

class XdripBgEstimateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_NEW_BG_ESTIMATE) return

        val timestamp = intent.getLongExtra(EXTRA_TIMESTAMP, 0L)
        val bgEstimate = intent.getDoubleExtra(EXTRA_BG_ESTIMATE, Double.NaN)
        if (timestamp <= 0L || bgEstimate.isNaN() || bgEstimate <= 0.0) return

        val direction = intent.getStringExtra(EXTRA_BG_SLOPE_NAME).orEmpty()
        val glucosePayload = JSONObject()
            .put("externalId", "xdrip-$timestamp")
            .put("source", "xdrip")
            .put("timestamp", timestamp)
            .put("sgv", bgEstimate.roundToInt())
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
            setReceiverEnabledState(context, XdripBgEstimateReceiver::class.java, enabled)
        }

        const val ACTION_NEW_BG_ESTIMATE = "com.eveningoutpost.dexdrip.BgEstimate"
        const val EXTRA_BG_ESTIMATE = "com.eveningoutpost.dexdrip.Extras.BgEstimate"
        const val EXTRA_BG_SLOPE_NAME = "com.eveningoutpost.dexdrip.Extras.BgSlopeName"
        const val EXTRA_TIMESTAMP = "com.eveningoutpost.dexdrip.Extras.Time"
    }
}
