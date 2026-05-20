package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.pravera.flutter_foreground_task.service.ForegroundService
import org.json.JSONArray
import org.json.JSONObject

class AapsTreatmentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in SUPPORTED_ACTIONS) return

        val treatmentsJson = intent.getStringExtra(EXTRA_TREATMENT)
            ?: intent.getStringExtra(EXTRA_TREATMENTS)
            ?: intent.getStringExtra(EXTRA_PAYLOAD)
            ?: return
        val data = try {
            parseTreatments(treatmentsJson)
        } catch (_: Exception) {
            return
        }

        val eventPayload = JSONObject()
            .put("external_event", "native_receiver")
            .put(
                "data",
                JSONObject()
                    .put("kind", "treatments")
                    .put("data", JSONObject().put("data", data)),
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
            setReceiverEnabledState(context, AapsTreatmentReceiver::class.java, enabled)
        }

        private fun parseTreatments(payload: String): Any {
            val trimmed = payload.trim()
            return if (trimmed.startsWith("[")) {
                JSONArray(trimmed)
            } else {
                JSONObject(trimmed)
            }
        }

        private val SUPPORTED_ACTIONS = setOf(
            ACTION_NEW_FOOD,
            ACTION_NEW_TREATMENT,
            ACTION_EXTERNAL_NEW_TREATMENTS,
        )

        const val ACTION_NEW_FOOD = "info.nightscout.client.NEW_FOOD"
        const val ACTION_NEW_TREATMENT = "info.nightscout.client.NEW_TREATMENT"
        const val ACTION_EXTERNAL_NEW_TREATMENTS =
            "app.aaps.intent.action.NEW_TREATMENTS"
        const val EXTRA_TREATMENT = "treatment"
        const val EXTRA_TREATMENTS = "treatments"
        const val EXTRA_PAYLOAD = "payload"
    }
}
