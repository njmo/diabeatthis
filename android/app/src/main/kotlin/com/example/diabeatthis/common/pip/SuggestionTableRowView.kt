package com.example.diabeatthis.common.pip

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView

class SuggestionTableRowView(context: Context, label: String, value: String) : LinearLayout(context) {
    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        val padding = (8 * resources.displayMetrics.density).toInt()
        setPadding(0, padding, 0, padding)
        addView(TextView(context).apply {
            text = label
            textSize = 13f
            setTextColor(Color.rgb(174, 192, 205))
        }, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        addView(TextView(context).apply {
            text = value
            textSize = 13f
            gravity = Gravity.RIGHT
            setTextColor(Color.WHITE)
            setPadding(padding, 0, 0, 0)
        }, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
    }
}
