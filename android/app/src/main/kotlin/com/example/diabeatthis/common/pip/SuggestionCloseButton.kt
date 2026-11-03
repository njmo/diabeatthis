package com.example.diabeatthis.common.pip

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import android.widget.LinearLayout

class SuggestionCloseButton(context: Context, label: String, onClose: () -> Unit) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        strokeWidth = 2 * resources.displayMetrics.density
        strokeCap = Paint.Cap.ROUND
    }

    init {
        val size = (48 * resources.displayMetrics.density).toInt()
        layoutParams = LinearLayout.LayoutParams(size, size)
        contentDescription = label
        isFocusable = true
        setOnClickListener { onClose() }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val inset = width * 0.36f
        canvas.drawLine(inset, inset, width - inset, height - inset, paint)
        canvas.drawLine(width - inset, inset, inset, height - inset, paint)
    }
}
