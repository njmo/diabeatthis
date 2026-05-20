package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.pravera.flutter_foreground_task.service.ForegroundService
import org.json.JSONObject

class AapsDeviceStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in SUPPORTED_ACTIONS) return

        val deviceStatus = intent.getStringExtra(EXTRA_DEVICE_STATUS)
            ?: intent.getStringExtra(EXTRA_PAYLOAD)
            ?: return
        val data = try {
            JSONObject(deviceStatus)
        } catch (_: Exception) {
            return
        }

        val eventPayload = JSONObject()
            .put("external_event", "native_receiver")
            .put(
                "data",
                JSONObject()
                    .put("kind", "device_status")
                    .put("data", data),
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
            setReceiverEnabledState(
                context,
                AapsDeviceStatusReceiver::class.java,
                enabled,
            )
        }

        const val ACTION_NEW_DEVICE_STATUS = "info.nightscout.client.NEW_DEVICESTATUS"
        const val ACTION_EXTERNAL_NEW_DEVICE_STATUS =
            "app.aaps.intent.action.NEW_DEVICE_STATUS"
        const val EXTRA_DEVICE_STATUS = "devicestatus"
        const val EXTRA_PAYLOAD = "payload"

        private val SUPPORTED_ACTIONS = setOf(
            ACTION_NEW_DEVICE_STATUS,
            ACTION_EXTERNAL_NEW_DEVICE_STATUS,
        )
    }
}
