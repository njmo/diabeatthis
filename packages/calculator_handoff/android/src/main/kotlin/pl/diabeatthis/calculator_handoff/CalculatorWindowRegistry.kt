package pl.diabeatthis.calculator_handoff

import java.lang.ref.WeakReference
import android.content.Context
import android.util.Log

/** Shared by the UI engine and the foreground engine in the same process. */
object CalculatorWindowRegistry {
    internal var diagnosticContext: Context? = null

    private fun trace(message: String, warning: Boolean = false) {
        if (warning) Log.w("CalculatorHandoff", message)
        else Log.i("CalculatorHandoff", message)
        diagnosticContext?.let { AapsDiagnosticJournal.append(it, "pip", message) }
    }

    private var owner = WeakReference<CalculatorWindow>(null)
    private var sessionId: String? = null
    private var ready = false
    private val pending = LinkedHashMap<String, List<Boolean>>()

    fun attach(id: String?, window: CalculatorWindow) {
        sessionId = id
        owner = WeakReference(window)
        ready = false
    }

    fun markReady(id: String?) {
        if (id != sessionId) return
        ready = true
        trace("Checklist ready session=$id")
        apply()
    }

    fun detach(window: CalculatorWindow) {
        if (owner.get() === window) {
            owner.clear()
            sessionId = null
            ready = false
        }
    }

    fun update(id: String, completed: List<Boolean>) {
        if (pending[id] == completed) return
        trace("Checklist update session=$id completed=$completed")
        pending[id] = completed
        while (pending.size > 20) pending.remove(pending.keys.first())
        if (id == sessionId) apply()
    }

    fun dismiss(id: String?) {
        if (id != null) pending.remove(id)
        if (id != null && id == sessionId) {
            trace("Dismiss cancelled or superseded instruction session=$id")
            owner.get()?.closeCalculatorWindow()
        }
    }

    private fun apply() {
        if (!ready) return
        val window = owner.get() ?: return
        val completed = pending[sessionId] ?: return
        if (completed.size != window.checklistSize) {
            trace("Ignore checklist with changed requirements session=$sessionId", warning = true)
            return
        }
        window.updateChecklist(completed)
        trace("Checklist applied session=$sessionId completed=$completed")
        if (completed.isNotEmpty() && completed.all { it }) {
            // Briefly show the last checkmark before dismissing the completed list.
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (owner.get() === window && pending[sessionId]?.all { it } == true) {
                    trace("Dismiss completed checklist session=$sessionId")
                    window.closeCalculatorWindow()
                }
            }, 800)
        }
    }
}
