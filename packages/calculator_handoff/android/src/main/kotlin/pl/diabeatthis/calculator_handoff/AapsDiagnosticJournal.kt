package pl.diabeatthis.calculator_handoff

import android.content.Context
import android.util.Log
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/** Bounded app-private trace shared by the receiver and both Flutter engines. */
object AapsDiagnosticJournal {
    private const val MAX_BYTES = 1024L * 1024
    private const val MAX_ROTATED_FILES = 7
    private val executor = Executors.newSingleThreadExecutor()

    fun append(context: Context, source: String, message: String) {
        val directory = context.filesDir
        val clean = message.take(2048).replace('\n', ' ').replace('\r', ' ')
        val line = "${System.currentTimeMillis()} [$source] $clean\n"
        executor.execute {
            try {
                val file = journalFile(directory, 0)
                if (file.length() >= MAX_BYTES) {
                    journalFile(directory, MAX_ROTATED_FILES).delete()
                    for (index in MAX_ROTATED_FILES downTo 1) {
                        val previous = journalFile(directory, index - 1)
                        if (previous.exists() && !previous.renameTo(journalFile(directory, index))) {
                            throw IOException("Could not rotate diagnostic journal")
                        }
                    }
                }
                file.appendText(line)
            } catch (error: IOException) {
                Log.w("AapsDiagnosticJournal", "Could not save trace")
            }
        }
    }

    fun afterPendingWrites(block: () -> Unit) {
        executor.execute { block() }
    }

    fun export(context: Context, onComplete: (String?) -> Unit) {
        val directory = context.filesDir
        val cache = context.cacheDir
        executor.execute {
            val files = (MAX_ROTATED_FILES downTo 0).map { journalFile(directory, it) }
                .filter { it.isFile }
            onComplete(if (files.isEmpty()) null else try {
                val snapshot = File.createTempFile("aaps-pip-", ".txt", cache)
                snapshot.outputStream().use { output ->
                    files.forEach { file -> file.inputStream().use { it.copyTo(output) } }
                }
                snapshot.path
            } catch (error: IOException) {
                Log.w("AapsDiagnosticJournal", "Could not export trace")
                null
            })
        }
    }

    private fun journalFile(directory: File, index: Int) =
        File(directory, "aaps-pip-diagnostics.$index.log")
}
