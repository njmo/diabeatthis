package com.example.diabeatthis.common.pip

import pl.diabeatthis.calculator_handoff.CalculatorWindowRegistry

/** The shared registry can also be reached directly from the foreground engine. */
object SuggestionPipSession {
    fun attach(owner: SuggestionPipActivity, id: String?) = CalculatorWindowRegistry.attach(id, owner)
    fun detach(owner: SuggestionPipActivity) = CalculatorWindowRegistry.detach(owner)
    fun dismiss(id: String?) = CalculatorWindowRegistry.dismiss(id)
}
