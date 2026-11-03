package pl.diabeatthis.calculator_handoff

import java.lang.ref.WeakReference
import android.util.Log

/** Shared by the UI engine and the foreground engine in the same process. */
object CalculatorWindowRegistry {
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
        Log.i("CalculatorHandoff", "Checklist update session=$id completed=$completed")
        pending[id] = completed
        while (pending.size > 20) pending.remove(pending.keys.first())
        if (id == sessionId) apply()
    }

    fun dismiss(id: String?) {
        if (id != null) pending.remove(id)
        if (id != null && id == sessionId) {
            Log.i("CalculatorHandoff", "Dismiss cancelled or superseded instruction session=$id")
            owner.get()?.closeCalculatorWindow()
        }
    }

    private fun apply() {
        if (!ready) return
        val window = owner.get() ?: return
        val completed = pending[sessionId] ?: return
        if (completed.size != window.checklistSize) {
            Log.w("CalculatorHandoff", "Ignore checklist with changed requirements session=$sessionId")
            return
        }
        window.updateChecklist(completed)
        if (completed.isNotEmpty() && completed.all { it }) {
            // Briefly show the last checkmark before dismissing the completed list.
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (owner.get() === window && pending[sessionId]?.all { it } == true) {
                    Log.i("CalculatorHandoff", "Dismiss completed checklist session=$sessionId")
                    window.closeCalculatorWindow()
                }
            }, 800)
        }
    }
}
