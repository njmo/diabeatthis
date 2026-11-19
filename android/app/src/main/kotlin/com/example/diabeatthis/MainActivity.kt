package com.example.diabeatthis

import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import com.example.diabeatthis.common.pip.SuggestionPipChannel
import com.example.diabeatthis.common.pip.SuggestionOverlayChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SuggestionPipChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        SuggestionOverlayChannel(this, flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "pl.diabeatthis.app/notification_sound",
        ).setMethodCallHandler { call, result ->
            if (call.method == "playFamilyChat") {
                try {
                    playFamilyChatSound()
                    result.success(null)
                } catch (_: Exception) {
                    result.error("notification_sound", null, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            XDRIP_RECEIVER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    XdripBgEstimateReceiver.setEnabled(this)
                    result.success(null)
                }

                "setDisabled" -> {
                    XdripBgEstimateReceiver.setDisabled(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AAPS_RECEIVER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    AapsDeviceStatusReceiver.setEnabled(this)
                    AapsGlucoseReceiver.setEnabled(this)
                    AapsTreatmentReceiver.setEnabled(this)
                    result.success(null)
                }

                "setDisabled" -> {
                    AapsDeviceStatusReceiver.setDisabled(this)
                    AapsGlucoseReceiver.setDisabled(this)
                    AapsTreatmentReceiver.setDisabled(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun playFamilyChatSound() {
        val notifications = getSystemService(NotificationManager::class.java)
        val audio = getSystemService(AudioManager::class.java)
        if (!notifications.areNotificationsEnabled() ||
            audio.ringerMode != AudioManager.RINGER_MODE_NORMAL
        ) return

        val channel = notifications.getNotificationChannel("family_chat_messages")
        if (channel != null && channel.importance < NotificationManager.IMPORTANCE_DEFAULT) return
        val sound = if (channel != null) channel.sound
            else RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_NOTIFICATION)
        if (sound == null) return
        RingtoneManager.getRingtone(this, sound)?.apply {
            audioAttributes = channel?.audioAttributes ?: AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()
            play()
        }
    }

    private companion object {
        const val AAPS_RECEIVER_CHANNEL = "pl.diabeatthis.app/aaps_receiver"
        const val XDRIP_RECEIVER_CHANNEL = "pl.diabeatthis.app/xdrip_receiver"
    }
}
