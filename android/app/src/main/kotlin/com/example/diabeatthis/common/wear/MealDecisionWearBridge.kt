package com.example.diabeatthis.common.wear

import android.app.Activity
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.TaskCompletionSource
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import pl.diabeatthis.wearnotifications.MealDecisionWearNotificationsPlugin

class MealDecisionWearBridge(private val context: Activity, messenger: BinaryMessenger) {
    private val timingEnabled = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
    private val power = context.getSystemService(PowerManager::class.java)
    private val keyguard = context.getSystemService(KeyguardManager::class.java)
    private val client = Wearable.getMessageClient(context.applicationContext)
    private val nodes = Wearable.getNodeClient(context.applicationContext)
    private val channel = MethodChannel(messenger, "pl.diabeatthis.app/meal_decision_watch")
    private val main = Handler(Looper.getMainLooper())
    private val service = MessageClient.RpcService { _, path, bytes ->
        if (path != PATH) null else exchange(bytes)
    }
    private var closed = false

    init {
        client.addRpcService(service, PATH).addOnSuccessListener {
            if (!closed) MealDecisionWearNotificationsPlugin.setInvitationBridge(this, true)
        }
        channel.setMethodCallHandler { call, result ->
            if (call.method == "isPhoneInteractive") {
                result.success(power.isInteractive && !keyguard.isKeyguardLocked)
            } else if (call.method == "postMealSummary") {
                val mealId = call.argument<Number>("mealId")?.toLong()
                val title = call.argument<String>("title")
                val start = call.argument<Boolean>("start") == true
                result.success(mealId != null && mealId > 0 &&
                    !title.isNullOrBlank() && postMealSummary(mealId, title, start))
            } else if (call.method == "takeMealSummary") {
                val mealId = context.intent?.getLongExtra(EXTRA_SUMMARY, 0L) ?: 0L
                val start = context.intent?.getBooleanExtra(EXTRA_START, false) == true
                context.intent?.removeExtra(EXTRA_SUMMARY)
                context.intent?.removeExtra(EXTRA_START)
                result.success(if (mealId > 0) mapOf("mealId" to mealId, "start" to start) else null)
            } else if (call.method != "inboxChanged") {
                result.notImplemented()
            } else {
                val added = call.argument<List<String>>("added").orEmpty()
                val removed = call.argument<List<String>>("removed").orEmpty()
                result.success(null)
                nodes.connectedNodes.addOnSuccessListener { peers ->
                    if (!closed) {
                        val notifyWatch = !power.isInteractive || keyguard.isKeyguardLocked
                        if (timingEnabled && added.isNotEmpty()) {
                            Log.i("MealDecisionTiming", "watch.alert.inbox notifyWatch=$notifyWatch")
                        }
                        for (peer in peers) {
                            client.sendMessage(peer.id, INBOX_CHANGED, ByteArray(0))
                            if (notifyWatch) {
                                for (id in added) client.sendMessage(peer.id, INVITATION, id.encodeToByteArray())
                            }
                            for (id in removed) client.sendMessage(peer.id, REMOVE_INVITATION, id.encodeToByteArray())
                        }
                    }
                }
            }
        }
    }

    fun onPhoneIntent(intent: Intent) {
        if (intent.hasExtra(EXTRA_SUMMARY)) {
            channel.invokeMethod("phoneMealSummaryOpened", null)
        }
    }

    private fun postMealSummary(mealId: Long, title: String, start: Boolean): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return false
        val channelId = "watch_meal_summary"
        manager.createNotificationChannel(
            NotificationChannel(channelId, title, NotificationManager.IMPORTANCE_HIGH),
        )
        if (manager.getNotificationChannel(channelId).importance ==
            NotificationManager.IMPORTANCE_NONE) return false
        val open = Intent(context, context.javaClass)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            .putExtra(EXTRA_SUMMARY, mealId)
            .putExtra(EXTRA_START, start)
        val pending = PendingIntent.getActivity(context, mealId.hashCode(), open,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val icon = context.applicationInfo.icon
        return runCatching {
            manager.notify("watch-meal-summary", mealId.hashCode(),
                Notification.Builder(context, channelId)
                    .setSmallIcon(icon)
                    .setContentTitle(title)
                    .setContentIntent(pending)
                    .setAutoCancel(true)
                    .setLocalOnly(true)
                    .setVisibility(Notification.VISIBILITY_PRIVATE)
                    .build())
            true
        }.getOrDefault(false)
    }

    fun close() {
        closed = true
        MealDecisionWearNotificationsPlugin.setInvitationBridge(this, false)
        channel.setMethodCallHandler(null)
        client.removeRpcService(service)
    }

    private fun exchange(bytes: ByteArray): Task<ByteArray> {
        val completion = TaskCompletionSource<ByteArray>()
        val started = SystemClock.elapsedRealtime()
        fun reply(map: Map<*, *>) {
            completion.trySetResult(JSONObject(map).toString().encodeToByteArray())
        }

        main.post {
            if (closed) {
                reply(mapOf("version" to 1, "status" to "unavailable"))
                return@post
            }

            val request = try {
                require(bytes.size <= 2048)
                val json = JSONObject(bytes.decodeToString())
                json.keys().asSequence().associateWith { json.opt(it) }
                    .filterValues { it != JSONObject.NULL }
            } catch (_: Exception) {
                reply(mapOf("version" to 1, "status" to "invalidRequest"))
                return@post
            }

            val action = request["action"]?.toString()
            val traced = timingEnabled && action in setOf("list", "open", "claim", "respond")
            if (traced) Log.i("MealDecisionTiming", "watch.phone.rpc.$action.start")
            channel.invokeMethod("exchange", request, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (traced) Log.i("MealDecisionTiming",
                        "watch.phone.rpc.$action.done ms=${SystemClock.elapsedRealtime() - started}")
                    if (result is Map<*, *> && !closed) reply(result)
                    else unavailable()
                }

                override fun error(code: String, message: String?, details: Any?) = unavailable()
                override fun notImplemented() = unavailable()

                private fun unavailable() {
                    reply(mapOf("version" to 1, "status" to "unavailable"))
                }
            })
        }
        return completion.task
    }

    private companion object {
        const val PATH = "/diabeatthis/meal-decision"
        const val EXTRA_SUMMARY = "pl.diabeatthis.app.watchSummaryMealId"
        const val EXTRA_START = "pl.diabeatthis.app.watchStartMeal"
        const val INBOX_CHANGED = "/diabeatthis/meal-decision/inbox-changed"
        const val INVITATION = "/diabeatthis/meal-decision/invitation"
        const val REMOVE_INVITATION = "/diabeatthis/meal-decision/remove-invitation"
    }
}
