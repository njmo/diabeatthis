package com.example.diabeatthis.common.pip

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class SuggestionOverlayChannel(activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "pl.diabeatthis.app/suggestion_overlay").setMethodCallHandler { call, result ->
            if (call.method != "openAaps") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val labels = call.argument<List<String>>("labels") ?: emptyList()
            val values = call.argument<List<String>>("values") ?: emptyList()
            val title = call.argument<String>("title")
            val closeLabel = call.argument<String>("closeLabel")
            val packageName = call.argument<String>("packageName") ?: ""
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || labels.isEmpty() ||
                labels.size != values.size || labels.size > 3 || title.isNullOrBlank() || closeLabel.isNullOrBlank()) {
                result.success(false)
                return@setMethodCallHandler
            }
            if (Settings.canDrawOverlays(activity)) {
                result.success(SuggestionOverlayWindow.open(activity, title, closeLabel, labels, values, packageName))
            } else {
                val receiver = object : ResultReceiver(Handler(Looper.getMainLooper())) {
                    override fun onReceiveResult(resultCode: Int, data: Bundle?) {
                        result.success(resultCode == 1)
                    }
                }
                val intent = Intent(activity, SuggestionOverlayPermissionActivity::class.java)
                    .putStringArrayListExtra("labels", ArrayList(labels))
                    .putStringArrayListExtra("values", ArrayList(values))
                    .putExtra("title", title)
                    .putExtra("closeLabel", closeLabel)
                    .putExtra("packageName", packageName)
                    .putExtra("receiver", receiver)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                try {
                    activity.startActivity(intent)
                } catch (_: RuntimeException) {
                    result.success(false)
                }
            }
        }
    }
}
