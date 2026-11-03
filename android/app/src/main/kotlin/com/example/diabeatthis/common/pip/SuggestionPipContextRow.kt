package com.example.diabeatthis.common.pip

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils

/** Activity context above its dose proposal, using the complete card width. */
class SuggestionPipContextRow {
    private val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG)

    fun draw(canvas: Canvas, proposal: String, activity: String, left: Float, top: Float, right: Float, height: Float) {
        val availableWidth = (right - left).toInt().coerceAtLeast(1)
        paint.color = Color.WHITE
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textSize = height * 0.22f
        val activityLayout = StaticLayout.Builder.obtain(activity, 0, activity.length, paint, availableWidth)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setMaxLines(2)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
        canvas.save()
        canvas.translate(left, top + height * 0.05f)
        activityLayout.draw(canvas)
        canvas.restore()
        paint.color = Color.rgb(243, 201, 106)
        paint.textSize = height * 0.25f
        paint.typeface = Typeface.DEFAULT_BOLD
        val measured = paint.measureText(proposal)
        if (measured > availableWidth) paint.textSize *= availableWidth / measured
        val baseline = top + height * 0.90f - paint.descent()
        canvas.drawText(proposal, left, baseline, paint)
    }
}
