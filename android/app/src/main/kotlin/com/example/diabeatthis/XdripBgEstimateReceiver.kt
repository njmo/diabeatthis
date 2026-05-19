package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
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
            val component = ComponentName(context, XdripBgEstimateReceiver::class.java)
            val state = if (enabled) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }

            context.packageManager.setComponentEnabledSetting(
                component,
                state,
                PackageManager.DONT_KILL_APP,
            )
        }

        const val ACTION_NEW_BG_ESTIMATE = "com.eveningoutpost.dexdrip.BgEstimate"
        const val EXTRA_BG_ESTIMATE = "com.eveningoutpost.dexdrip.Extras.BgEstimate"
        const val EXTRA_BG_SLOPE_NAME = "com.eveningoutpost.dexdrip.Extras.BgSlopeName"
        const val EXTRA_TIMESTAMP = "com.eveningoutpost.dexdrip.Extras.Time"
    }
}
