package com.example.diabeatthis.common.pip

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import android.util.Log
import android.util.Rational
import pl.diabeatthis.calculator_handoff.CalculatorWindow
import pl.diabeatthis.calculator_handoff.CalculatorWindowRegistry

/** Uses system PiP, not application overlays hidden by AAPS. */
class SuggestionPipActivity : Activity(), CalculatorWindow {
    private lateinit var table: SuggestionPipTableView
    override val checklistSize: Int
        get() = intent.getStringArrayListExtra("labels")?.size ?: 0
    private val handler = Handler(Looper.getMainLooper())
    private var reported = false
    private var enteredPip = false
    private val timeout = Runnable { complete(false, "PiP entry timed out") }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reported = savedInstanceState?.getBoolean("handoffReported") ?: false
        enteredPip = savedInstanceState?.getBoolean("enteredPip") ?: false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            complete(false, "PiP is unsupported")
            return
        }
        val labels = intent.getStringArrayListExtra("labels") ?: arrayListOf()
        val values = intent.getStringArrayListExtra("values") ?: arrayListOf()
        if (labels.isEmpty() || labels.size != values.size) {
            complete(false, "Invalid suggestion rows")
            return
        }
        SuggestionPipSession.attach(this, intent.getStringExtra("sessionId"))
        table = SuggestionPipTableView(this, intent.getStringExtra("title") ?: "", labels, values)
        setContentView(table)
        if (reported && enteredPip) CalculatorWindowRegistry.markReady(intent.getStringExtra("sessionId"))
    }

    override fun onResume() {
        super.onResume()
        if (reported || isFinishing || enteredPip) return
        window.decorView.post {
            if (reported || isFinishing) return@post
            try {
                val rowCount = intent.getStringArrayListExtra("labels")?.size ?: 3
                val ratio = when (rowCount) {
                    1 -> Rational(239, 100)
                    2 -> Rational(11, 5)
                    else -> Rational(2, 1)
                }
                val params = PictureInPictureParams.Builder().setAspectRatio(ratio)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) params.setSeamlessResizeEnabled(false)
                handler.postDelayed(timeout, 2500)
                if (!enterPictureInPictureMode(params.build())) complete(false, "System rejected PiP entry")
            } catch (error: RuntimeException) {
                Log.w("SuggestionPip", "Could not enter PiP", error)
                complete(false, "PiP entry failed")
            }
        }
    }

    override fun onPictureInPictureModeChanged(inPip: Boolean, configuration: Configuration) {
        super.onPictureInPictureModeChanged(inPip, configuration)
        if (inPip) {
            if (reported) return
            enteredPip = true
            try {
                val launch = packageManager.getLaunchIntentForPackage(intent.getStringExtra("packageName") ?: "")
                if (launch == null) complete(false, "AAPS is unavailable")
                else {
                    startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    complete(true, "PiP entered and AAPS opened")
                }
            } catch (error: RuntimeException) {
                Log.w("SuggestionPip", "Could not open AAPS", error)
                complete(false, "AAPS launch failed")
            }
        } else if (enteredPip) {
            finishAndRemoveTask()
        }
    }

    @Suppress("DEPRECATION")
    private fun complete(opened: Boolean, reason: String) {
        if (reported) return
        reported = true
        handler.removeCallbacks(timeout)
        Log.i("SuggestionPip", reason)
        intent.getParcelableExtra<ResultReceiver>("receiver")?.send(if (opened) 1 else 0, Bundle.EMPTY)
        if (!opened) finishAndRemoveTask()
        else CalculatorWindowRegistry.markReady(intent.getStringExtra("sessionId"))
    }

    override fun updateChecklist(completed: List<Boolean>) {
        if (::table.isInitialized) table.setCompleted(completed)
    }

    override fun closeCalculatorWindow() {
        finishAndRemoveTask()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("handoffReported", reported)
        outState.putBoolean("enteredPip", enteredPip)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        SuggestionPipSession.detach(this)
        if (!isChangingConfigurations) complete(false, "PiP activity destroyed before handoff")
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
