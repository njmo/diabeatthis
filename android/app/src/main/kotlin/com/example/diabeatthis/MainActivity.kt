package com.example.diabeatthis

import android.content.ActivityNotFoundException
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AAPS_LAUNCHER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAaps" -> result.success(openAaps())
                else -> result.notImplemented()
            }
        }
    }

    private fun openAaps(): String {
        val launchIntent = packageManager.getLaunchIntentForPackage(AAPS_PACKAGE)
            ?: return "unavailable"

        return try {
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            startActivity(launchIntent)
            "opened"
        } catch (_: ActivityNotFoundException) {
            "unavailable"
        } catch (_: RuntimeException) {
            "failed"
        }
    }

    private companion object {
        const val AAPS_LAUNCHER_CHANNEL = "diabeatthis/aaps_launcher"
        const val AAPS_PACKAGE = "info.nightscout.androidaps"
    }
}
