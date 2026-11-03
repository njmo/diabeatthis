package com.example.diabeatthis.common.pip

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout

/** One app-owned overlay at a time, above the external calculator. */
object SuggestionOverlayWindow {
    private var window: View? = null
    private var manager: WindowManager? = null

    fun open(activity: Activity, title: String, closeLabel: String, labels: List<String>, values: List<String>, packageName: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || !Settings.canDrawOverlays(activity)) return false
        val launch = activity.packageManager.getLaunchIntentForPackage(packageName) ?: return false
        dismiss()
        val context = activity.applicationContext
        val density = context.resources.displayMetrics.density
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = GradientDrawable().apply {
                setColor(Color.rgb(20, 28, 36))
                cornerRadius = 14 * density
            }
            clipToOutline = true
            elevation = 8 * density
            addView(SuggestionHeaderView(context, title, closeLabel) { dismiss() })
            addView(SuggestionTableView(context, labels, values))
        }
        val availableWidth = context.resources.displayMetrics.widthPixels - (24 * density).toInt()
        val params = WindowManager.LayoutParams(
            minOf((300 * density).toInt(), availableWidth), WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.RIGHT
            x = (12 * density).toInt()
            y = (12 * density).toInt()
        }
        return try {
            wm.addView(card, params)
            manager = wm
            window = card
            activity.startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: RuntimeException) {
            dismiss()
            false
        }
    }

    fun dismiss() {
        val current = window
        window = null
        try {
            if (current != null) manager?.removeView(current)
        } catch (_: IllegalArgumentException) {
            // Android may have removed the window after access was revoked.
        }
        manager = null
    }
}
