package pl.diabeatthis.foreground_power_lock

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class ForegroundPowerLockPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var applicationContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(
            binding.binaryMessenger,
            "pl.diabeatthis/foreground_power_lock",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        CollectTickWakeLock.release()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "acquireCollectTick" -> {
                val timeoutMillis = call.argument<Number>("timeoutMillis")?.toLong()
                CollectTickWakeLock.acquire(applicationContext, timeoutMillis)
                result.success(null)
            }

            "releaseCollectTick" -> {
                CollectTickWakeLock.release()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }
}
