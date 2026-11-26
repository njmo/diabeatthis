package pl.diabeatthis.calculator_handoff

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class CalculatorHandoffPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "pl.diabeatthis.app/calculator_handoff").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "dismiss" -> {
                        CalculatorWindowRegistry.dismiss(call.argument<String>("sessionId"))
                        result.success(null)
                    }
                    "update" -> {
                        val id = call.argument<String>("sessionId")
                        val completed = call.argument<List<Boolean>>("completed")
                        if (id == null || completed == null) result.error("invalid_state", "Missing calculator state", null)
                        else {
                            CalculatorWindowRegistry.update(id, completed)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
