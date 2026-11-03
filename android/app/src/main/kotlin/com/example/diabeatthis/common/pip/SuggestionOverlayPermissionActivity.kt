package com.example.diabeatthis.common.pip

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.ResultReceiver
import android.provider.Settings

/** Requests overlay access and resumes the same handoff on return. */
class SuggestionOverlayPermissionActivity : Activity() {
    private var reported = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Settings.canDrawOverlays(this)) {
            showSuggestion()
        } else if (savedInstanceState == null) {
            try {
                @Suppress("DEPRECATION")
                startActivityForResult(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")), 1)
            } catch (_: RuntimeException) {
                complete(false)
            }
        }
    }

    @Deprecated("Required for the special-access settings result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1) showSuggestion()
    }

    private fun showSuggestion() {
        val labels = intent.getStringArrayListExtra("labels") ?: arrayListOf()
        val values = intent.getStringArrayListExtra("values") ?: arrayListOf()
        val title = intent.getStringExtra("title")
        val closeLabel = intent.getStringExtra("closeLabel")
        if (!Settings.canDrawOverlays(this) || labels.isEmpty() || labels.size != values.size ||
            title.isNullOrBlank() || closeLabel.isNullOrBlank()) {
            complete(false)
            return
        }
        complete(SuggestionOverlayWindow.open(this, title, closeLabel, labels, values, intent.getStringExtra("packageName") ?: ""))
    }

    @Suppress("DEPRECATION")
    private fun complete(opened: Boolean) {
        if (reported) return
        reported = true
        intent.getParcelableExtra<ResultReceiver>("receiver")?.send(if (opened) 1 else 0, Bundle.EMPTY)
        finishAndRemoveTask()
    }

    override fun onDestroy() {
        if (!isChangingConfigurations) complete(false)
        super.onDestroy()
    }
}
