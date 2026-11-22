package pl.diabeatthis.wearnotifications;

import android.app.KeyguardManager;
import android.app.NotificationManager;
import android.content.Context;
import android.os.PowerManager;
import com.google.android.gms.tasks.Task;
import com.google.android.gms.tasks.Tasks;
import com.google.android.gms.wearable.CapabilityClient;
import com.google.android.gms.wearable.Node;
import com.google.android.gms.wearable.Wearable;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class MealDecisionWearNotificationsPlugin implements FlutterPlugin {
    private static final String CHANNEL = "pl.diabeatthis.app/wear_notifications";
    private static final String CAPABILITY = "diabeatthis_meal_decision_watch";
    private static final String INVITATION = "/diabeatthis/meal-decision/invitation";
    private MethodChannel channel;
    private static volatile Object invitationBridge;

    public static synchronized void setInvitationBridge(Object bridge, boolean ready) {
        if (ready) invitationBridge = bridge;
        else if (invitationBridge == bridge) invitationBridge = null;
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        Context context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler((call, result) -> {
            if ("wakePhone".equals(call.method)) {
                wakeForNotification(context, (String) call.arguments);
                result.success(null);
                return;
            }
            boolean answer = "answer".equals(call.method);
            if (!answer && !"invite".equals(call.method)) {
                result.notImplemented();
                return;
            }
            Object argument = call.arguments;
            if (!(argument instanceof String) || !((String) argument).matches("[a-f0-9]{32}")) {
                result.success(false);
                return;
            }
            if (!answer && (invitationBridge == null || isPhoneInUse(context))) {
                result.success(false);
                return;
            }
            byte[] request = ((String) argument).getBytes(StandardCharsets.UTF_8);
            Wearable.getCapabilityClient(context)
                .getCapability(CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .onSuccessTask(capability -> {
                    var client = Wearable.getMessageClient(context);
                    List<Task<byte[]>> sends = new ArrayList<>();
                    if (!answer && (invitationBridge == null || isPhoneInUse(context))) return Tasks.whenAllComplete(sends);
                    for (Node watch : capability.getNodes()) {
                        sends.add(client.sendRequest(watch.getId(), answer ? "/diabeatthis/meal-decision/answer" : INVITATION, request));
                    }
                    return Tasks.whenAllComplete(sends);
                })
                .addOnSuccessListener(sends -> {
                    boolean sent = false;
                    for (var send : sends) {
                        if (!send.isSuccessful()) continue;
                        if (send.getResult() instanceof byte[] response
                                && response.length == 1 && response[0] == 1) {
                            sent = true;
                        }
                    }
                    result.success(sent);
                })
                .addOnFailureListener(error -> result.success(false));
        });
    }

    private boolean isPhoneInUse(Context context) {
        var power = context.getSystemService(PowerManager.class);
        var keyguard = context.getSystemService(KeyguardManager.class);
        return power.isInteractive() && !keyguard.isKeyguardLocked();
    }

    @SuppressWarnings("deprecation")
    private void wakeForNotification(Context context, String channelId) {
        var notifications = context.getSystemService(NotificationManager.class);
        var power = context.getSystemService(PowerManager.class);
        if (android.os.Build.VERSION.SDK_INT < 26 || power.isInteractive()
                || !notifications.areNotificationsEnabled()
                || notifications.getCurrentInterruptionFilter() != NotificationManager.INTERRUPTION_FILTER_ALL) return;
        var notificationChannel = notifications.getNotificationChannel(channelId);
        if (notificationChannel == null
                || notificationChannel.getImportance() < NotificationManager.IMPORTANCE_HIGH) return;
        try {
            power.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "diabeatthis:meal-invitation").acquire(3000);
        } catch (SecurityException ignored) {
            // The posted notification remains available if the OS disallows wake-up.
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }
}
