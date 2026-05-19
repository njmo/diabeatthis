package com.example.diabeatthis

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

fun setReceiverEnabledState(
    context: Context,
    receiverClass: Class<out BroadcastReceiver>,
    enabled: Boolean,
) {
    val component = ComponentName(context, receiverClass)
    val state = if (enabled) {
        PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    } else {
        PackageManager.COMPONENT_ENABLED_STATE_DISABLED
    }

    context.packageManager.setComponentEnabledSetting(
        component,
        state,
        PackageManager.DONT_KILL_APP,
    )
}
