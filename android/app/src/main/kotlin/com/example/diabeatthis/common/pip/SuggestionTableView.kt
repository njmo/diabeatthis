package com.example.diabeatthis.common.pip

import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.LinearLayout

/** Only the supplied carbohydrate and schedule rows are rendered. */
class SuggestionTableView(context: Context, labels: List<String>, values: List<String>) : LinearLayout(context) {
    init {
        orientation = VERTICAL
        val density = resources.displayMetrics.density
        setPadding((12 * density).toInt(), 0, (12 * density).toInt(), (6 * density).toInt())
        labels.zip(values).forEach { (label, value) ->
            addView(View(context).apply { setBackgroundColor(Color.rgb(49, 63, 73)) }, LayoutParams(LayoutParams.MATCH_PARENT, density.toInt().coerceAtLeast(1)))
            addView(SuggestionTableRowView(context, label, value))
        }
    }
}
