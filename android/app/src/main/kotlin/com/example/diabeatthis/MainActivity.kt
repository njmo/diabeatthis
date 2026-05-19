package com.example.diabeatthis

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                    result.success(null)
                }

                "setDisabled" -> {
                    AapsDeviceStatusReceiver.setDisabled(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private companion object {
        const val AAPS_RECEIVER_CHANNEL = "pl.diabeatthis.app/aaps_receiver"
        const val XDRIP_RECEIVER_CHANNEL = "pl.diabeatthis.app/xdrip_receiver"
    }
}
