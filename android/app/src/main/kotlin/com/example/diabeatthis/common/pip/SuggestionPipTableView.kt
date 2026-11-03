package com.example.diabeatthis.common.pip

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextUtils
import android.view.View

/** Scales the heading and table to the actual PiP bounds rather than a full-screen layout. */
class SuggestionPipTableView(context: Context, private val title: String, private val labels: List<String>, private val values: List<String>, private val actionRows: List<Boolean>? = null, private val prominentRows: List<Boolean>? = null) : View(context) {
    private fun isActionRow(index: Int) = actionRows?.getOrNull(index) ?: (index < 2)

    private val contextRow = SuggestionPipContextRow()

    private var completed = List(labels.size) { false }

    fun setCompleted(value: List<Boolean>) {
        completed = List(labels.size) { value.getOrElse(it) { false } }
        contentDescription = title + ". " + labels.zip(values).mapIndexed { index, (label, value) ->
            if (isActionRow(index)) "${if (completed[index]) "☑" else "☐"} $label: $value"
            else "$label: $value"
        }.joinToString(". ")
        invalidate()
    }

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val logo = context.packageManager.getApplicationIcon(context.packageName)
    private val textPaint = android.text.TextPaint(Paint.ANTI_ALIAS_FLAG)

    init {
        contentDescription = title + ". " + labels.zip(values).joinToString(". ") { (label, value) -> "$label: $value" }
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        canvas.drawColor(Color.rgb(20, 28, 36))
        val padding = width * 0.025f
        val hasContext = prominentRows?.any { it } == true
        val contextCount = labels.indices.count { prominentRows?.getOrNull(it) == true }
        val headerHeight = height * if (hasContext) 0.18f else if (labels.size == 1) 0.36f else 0.25f
        val contextHeight = if (hasContext) height * 0.44f / contextCount else 0f
        val normalCount = labels.size - contextCount
        val rowHeight = if (normalCount > 0) (height - headerHeight - contextHeight * contextCount) / normalCount else 0f
        textPaint.color = Color.WHITE
        textPaint.typeface = Typeface.DEFAULT_BOLD
        textPaint.textSize = headerHeight * 0.38f
        val iconSize = headerHeight * 0.52f
        val iconTop = (headerHeight - iconSize) / 2
        logo.setBounds(padding.toInt(), iconTop.toInt(), (padding + iconSize).toInt(), (iconTop + iconSize).toInt())
        logo.draw(canvas)
        val titleLeft = padding * 2 + iconSize
        val titleWidth = width - padding - titleLeft
        val measuredTitleWidth = textPaint.measureText(title)
        if (measuredTitleWidth > titleWidth) {
            textPaint.textSize = maxOf(headerHeight * 0.28f, textPaint.textSize * titleWidth / measuredTitleWidth)
        }
        val heading = TextUtils.ellipsize(title, textPaint, titleWidth, TextUtils.TruncateAt.END)
        val titleBaseline = headerHeight / 2 - (textPaint.ascent() + textPaint.descent()) / 2
        canvas.drawText(heading.toString(), titleLeft, titleBaseline, textPaint)
        val displayOrder = labels.indices.sortedBy { if (prominentRows?.getOrNull(it) == true) 0 else 1 }
        var nextTop = headerHeight
        displayOrder.forEach { index ->
            val label = labels[index]
            val value = values[index]
            val top = nextTop
            if (prominentRows?.getOrNull(index) == true) {
                contextRow.draw(canvas, label, value, padding, top, width - padding, contextHeight)
                nextTop += contextHeight
                return@forEach
            }
            nextTop += rowHeight
            val isAction = isActionRow(index)
            paint.textSize = minOf(rowHeight * if (isAction) 0.40f else 0.34f, height * 0.19f)
            val box = minOf(rowHeight * 0.30f, height * 0.12f)
            val textLeft = padding * 2 + box
            val required = paint.measureText(label) + paint.measureText(value)
            val available = width - textLeft - padding * 2
            if (required > available) paint.textSize *= available / required
            paint.color = Color.rgb(49, 63, 73)
            canvas.drawLine(padding, top, width - padding, top, paint)
            val baseline = top + rowHeight / 2 - (paint.ascent() + paint.descent()) / 2
            val done = isAction && completed.getOrElse(index) { false }
            if (isAction) {
                val boxTop = top + (rowHeight - box) / 2
                paint.color = if (done) Color.rgb(106, 203, 163) else Color.rgb(174, 192, 205)
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = maxOf(1f, box * 0.08f)
                canvas.drawRoundRect(padding, boxTop, padding + box, boxTop + box, box * 0.12f, box * 0.12f, paint)
                if (done) {
                    canvas.drawLine(padding + box * 0.18f, boxTop + box * 0.52f, padding + box * 0.43f, boxTop + box * 0.76f, paint)
                    canvas.drawLine(padding + box * 0.43f, boxTop + box * 0.76f, padding + box * 0.84f, boxTop + box * 0.24f, paint)
                }
            }
            paint.style = Paint.Style.FILL
            paint.isStrikeThruText = done
            paint.color = if (done) Color.rgb(127, 151, 147) else Color.rgb(174, 192, 205)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(label, textLeft, baseline, paint)
            paint.color = if (done) Color.rgb(127, 151, 147) else Color.WHITE
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(value, width - padding, baseline, paint)
            paint.isStrikeThruText = false
        }
    }
}
