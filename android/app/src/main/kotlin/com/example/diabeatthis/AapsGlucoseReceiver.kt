package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.pravera.flutter_foreground_task.service.ForegroundService
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.roundToInt

class AapsGlucoseReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in SUPPORTED_ACTIONS) return

        val payload = glucosePayload(intent) ?: return
        NativeReceiverWakeLock.acquire(context)

        val readings = try {
            glucoseReadings(payload)
        } catch (_: Exception) {
            return
        }

        if (readings.isEmpty()) return
        readings.forEach { data -> sendGlucose(data) }
    }

    private fun sendGlucose(data: JSONObject) {
        val timestamp = data.optLong("date", 0L)
            .takeIf { it > 0L }
            ?: data.optLong("mills", 0L)
        val sgv = data.optDouble("sgv", Double.NaN)
            .takeUnless { it.isNaN() || it <= 0.0 }
            ?: data.optDouble("mgdl", Double.NaN)
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

        private fun glucoseReadings(payload: String): List<JSONObject> {
            val trimmed = payload.trim()
            return if (trimmed.startsWith("[")) {
                val array = JSONArray(trimmed)
                List(array.length()) { index -> array.getJSONObject(index) }
            } else {
                listOf(JSONObject(trimmed))
            }
        }

        private fun glucosePayload(intent: Intent): String? =
            intent.getStringExtra(EXTRA_ENTRIES)
                ?: intent.getStringExtra(EXTRA_SGVS)
                ?: intent.getStringExtra(EXTRA_PAYLOAD)
                ?: intent.getStringExtra(EXTRA_SGV)

        private val SUPPORTED_ACTIONS = setOf(
            ACTION_NEW_SGV,
            ACTION_EXTERNAL_NEW_GLUCOSE,
        )

        const val ACTION_NEW_SGV = "info.nightscout.client.NEW_SGV"
        const val ACTION_EXTERNAL_NEW_GLUCOSE =
            "app.aaps.intent.action.NEW_GLUCOSE"
        const val EXTRA_SGV = "sgv"
        const val EXTRA_SGVS = "sgvs"
        const val EXTRA_ENTRIES = "entries"
        const val EXTRA_PAYLOAD = "payload"
    }
}
