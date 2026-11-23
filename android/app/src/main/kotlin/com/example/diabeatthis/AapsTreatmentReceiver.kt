package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.util.Log
import com.pravera.flutter_foreground_task.service.ForegroundService
import org.json.JSONArray
import org.json.JSONObject
import pl.diabeatthis.calculator_handoff.AapsDiagnosticJournal

class AapsTreatmentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in SUPPORTED_ACTIONS) return

        val pending = goAsync()
        try {
            receiveTreatments(context, intent)
        } finally {
            AapsDiagnosticJournal.afterPendingWrites { pending.finish() }
        }
    }

    private fun receiveTreatments(context: Context, intent: Intent) {
        val traceId = SystemClock.elapsedRealtimeNanos().toString()
        val action = intent.action
        val treatmentsJson = intent.getStringExtra(EXTRA_TREATMENT)
            ?: intent.getStringExtra(EXTRA_TREATMENTS)
            ?: intent.getStringExtra(EXTRA_PAYLOAD)
            ?: run {
                trace(context, "broadcast=$traceId action=$action dropped=missing_payload", warning = true)
                return
            }
        val data = try {
            parseTreatments(treatmentsJson)
        } catch (_: Exception) {
            trace(context, "broadcast=$traceId action=$action dropped=invalid_json", warning = true)
            return
        }

        when (data) {
            is JSONObject -> logRecord(context, traceId, 0, data)
            is JSONArray -> for (index in 0 until data.length()) {
                logRecord(context, traceId, index, data.optJSONObject(index))
            }
        }
        val running = ForegroundService.isRunningServiceState.value
        trace(context, "broadcast=$traceId action=$action serviceRunning=$running")

        val eventPayload = JSONObject()
            .put("external_event", "native_receiver")
            .put("aapsTreatmentTrace", traceId)
            .put(
                "data",
                JSONObject()
                    .put("kind", "treatments")
                    .put("data", JSONObject().put("data", data)),
            )

        NativeReceiverWakeLock.acquire(context)
        ForegroundService.sendData(eventPayload.toString())
    }

    private fun logRecord(context: Context, traceId: String, index: Int, record: JSONObject?) {
        if (record == null) {
            trace(context, "broadcast=$traceId index=$index invalid=non_object", warning = true)
            return
        }
        val type = record.optString("eventType").take(40).replace(UNSAFE_FIELD, "_")
        val at = record.optLong("date", -1)
        val time = if (at < 0) record.optString("created_at").take(32).replace(UNSAFE_FIELD, "_") else at.toString()
        trace(context, "broadcast=$traceId index=$index type=$type at=$time " +
            "carbs=${record.optDouble("carbs").takeIf { it.isFinite() }} " +
            "insulin=${record.optDouble("insulin").takeIf { it.isFinite() }} " +
            "wizard=${!record.isNull("bolusCalculatorResult")} valid=${record.optBoolean("isValid", true)}")
    }

    private fun trace(context: Context, message: String, warning: Boolean = false) {
        if (warning) Log.w(TAG, message) else Log.i(TAG, message)
        AapsDiagnosticJournal.append(context, "receiver", message)
    }

    companion object {
        private val UNSAFE_FIELD = Regex("[^a-zA-Z0-9 +:._-]")
        private const val TAG = "AapsTreatmentTrace"

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
