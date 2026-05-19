package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import com.pravera.flutter_foreground_task.service.ForegroundService
import org.json.JSONObject

class AapsDeviceStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_NEW_DEVICE_STATUS) return

        val deviceStatus = intent.getStringExtra(EXTRA_DEVICE_STATUS) ?: return
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
            val component = ComponentName(context, AapsDeviceStatusReceiver::class.java)
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

        const val ACTION_NEW_DEVICE_STATUS = "info.nightscout.client.NEW_DEVICESTATUS"
        const val EXTRA_DEVICE_STATUS = "devicestatus"
    }
}
