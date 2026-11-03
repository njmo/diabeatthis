package com.example.diabeatthis.common.pip

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class SuggestionPipChannel(activity: Activity, messenger: BinaryMessenger) {
    init {
        MethodChannel(messenger, "pl.diabeatthis.app/suggestion_pip").setMethodCallHandler { call, result ->
            if (call.method == "dismiss") {
                SuggestionPipSession.dismiss(call.argument<String>("sessionId"))
                result.success(null)
            } else if (call.method != "openAaps") {
                result.notImplemented()
            } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                !activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                result.success(false)
            } else {
                val labels = call.argument<List<String>>("labels") ?: emptyList()
                val values = call.argument<List<String>>("values") ?: emptyList()
                val title = call.argument<String>("title")
                val closeLabel = call.argument<String>("closeLabel")
                val packageName = call.argument<String>("packageName") ?: ""
                if (labels.isEmpty() || labels.size != values.size || labels.size > 3 || title.isNullOrBlank() || closeLabel.isNullOrBlank()) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                val receiver = object : ResultReceiver(Handler(Looper.getMainLooper())) {
                    override fun onReceiveResult(resultCode: Int, data: Bundle?) {
                        result.success(resultCode == 1)
                    }
                }
                val launch = Intent(activity, SuggestionPipActivity::class.java)
                    .putStringArrayListExtra("labels", ArrayList(call.argument<List<String>>("labels") ?: emptyList()))
                    .putStringArrayListExtra("values", ArrayList(call.argument<List<String>>("values") ?: emptyList()))
                    .putExtra("prominentRows", call.argument<List<Boolean>>("prominentRows")?.toBooleanArray())
                    .putExtra("actionRows", call.argument<List<Boolean>>("actionRows")?.toBooleanArray())
                    .putExtra("packageName", call.argument<String>("packageName"))
                    .putExtra("sessionId", call.argument<String>("sessionId"))
                    .putExtra("title", title)
                    .putExtra("closeLabel", closeLabel)
                    .putExtra("receiver", receiver)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                try {
                    activity.startActivity(launch)
                } catch (_: RuntimeException) {
                    result.success(false)
                }
            }
        }
    }
}
