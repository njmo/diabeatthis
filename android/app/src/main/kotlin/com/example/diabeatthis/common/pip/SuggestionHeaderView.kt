package com.example.diabeatthis.common.pip

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.text.TextUtils
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class SuggestionHeaderView(context: Context, title: String, closeLabel: String, onClose: () -> Unit) : LinearLayout(context) {
    init {
        val density = resources.displayMetrics.density
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding((12 * density).toInt(), 0, 0, 0)
        addView(ImageView(context).apply {
            setImageDrawable(context.packageManager.getApplicationIcon(context.packageName))
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
        }, LayoutParams((24 * density).toInt(), (24 * density).toInt()))
        addView(TextView(context).apply {
            text = title
            textSize = 14f
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setPadding((8 * density).toInt(), (8 * density).toInt(), 0, (8 * density).toInt())
        }, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        addView(SuggestionCloseButton(context, closeLabel, onClose))
    }
}
