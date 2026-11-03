package pl.diabeatthis.calculator_handoff

interface CalculatorWindow {
    val checklistSize: Int
    fun updateChecklist(completed: List<Boolean>)
    fun closeCalculatorWindow()
}
