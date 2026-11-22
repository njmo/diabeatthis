package pl.diabeatthis.wear;

import android.Manifest;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.Context;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.PowerManager;
import com.google.android.gms.tasks.Task;
import com.google.android.gms.tasks.Tasks;
import com.google.android.gms.wearable.MessageEvent;
import com.google.android.gms.wearable.WearableListenerService;
import java.nio.charset.StandardCharsets;

public final class MealDecisionNotificationService extends WearableListenerService {
    static final String EXTRA_REQUEST_ID = "mealDecisionRequestId";
    static final String EXTRA_REQUEST_ACTION = "mealDecisionRequestAction";
    static final String CLAIM = "claim";
    static final String CLAIM_ON_PHONE = "claimOnPhone";
    static final String DECLINE = "decline";
    private static final String INVITATION = "/diabeatthis/meal-decision/invitation";
    private static final String ANSWER = "/diabeatthis/meal-decision/answer";
    private static final String REMOVE_INVITATION = "/diabeatthis/meal-decision/remove-invitation";
    private static final String CHANNEL = "watch_meal_decisions";

    @Override
    public void onMessageReceived(MessageEvent event) {
        if ("/diabeatthis/meal-decision/inbox-changed".equals(event.getPath())) {
            MealWatchTileService.getUpdater(this).requestUpdate(MealWatchTileService.class);
            return;
        }
        String path = event.getPath();
        if (!INVITATION.equals(path) && !REMOVE_INVITATION.equals(path)) return;
        String id = new String(event.getData(), StandardCharsets.UTF_8);
        if (!id.matches("[a-f0-9]{32}")) return;
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (REMOVE_INVITATION.equals(path)) {
            manager.cancel(id, 0);
            MealWatchTileService.removeInvitation(this, id);
            return;
        }
        MealWatchTileService.announceInvitation(this, id);
        showNotification(manager, id, false);
    }

    @Override
    public Task<byte[]> onRequest(String nodeId, String path, byte[] request) {
        boolean answer = ANSWER.equals(path);
        if (!answer && !INVITATION.equals(path)) return null;
        String id = new String(request, StandardCharsets.UTF_8);
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (!id.matches("[a-f0-9]{32}")) return Tasks.forResult(new byte[]{0});
        boolean posted;
        if (answer) {
            posted = showNotification(manager, id, true);
            MealWatchTileService.getUpdater(this).requestUpdate(MealWatchTileService.class);
        } else {
            MealWatchTileService.announceInvitation(this, id);
            posted = showNotification(manager, id, false);
        }
        return Tasks.forResult(new byte[]{(byte) (posted ? 1 : 0)});
    }

    private boolean showNotification(NotificationManager manager, String id, boolean answer) {
        if (!manager.areNotificationsEnabled() || (Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED)) return false;

        Context labels = WatchLanguage.savedLabels(this);
        String title = labels.getString(R.string.request_notification_title);
        manager.createNotificationChannel(
            new NotificationChannel(CHANNEL, title, NotificationManager.IMPORTANCE_HIGH));
        if (manager.getNotificationChannel(CHANNEL).getImportance() == NotificationManager.IMPORTANCE_NONE) {
            return false;
        }
        boolean alreadyPosted = false;
        for (var notification : manager.getActiveNotifications()) {
            if (id.equals(notification.getTag())) alreadyPosted = true;
        }
        var notification = new Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_meal_decision_notification)
            .setContentTitle(answer ? labels.getString(R.string.child_decision_title) : title)
            .setContentText(labels.getString(answer
                ? R.string.child_answer_notification_body : R.string.request_notification_body))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setTimeoutAfter(300000L)
            .setLocalOnly(true);
        if (answer) {
            var intent = new Intent(this, MealDecisionWatchActivity.class)
                .setData(Uri.parse("diabeatthis://meal-decision/" + id + "/answer"))
                .putExtra(EXTRA_REQUEST_ID, id)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
            notification.setContentIntent(PendingIntent.getActivity(this, 0, intent,
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT));
        } else {
            notification.addAction(new Notification.Action.Builder(null,
                labels.getString(R.string.notification_claim), actionIntent(id, CLAIM)).build())
                .addAction(new Notification.Action.Builder(null,
                    labels.getString(R.string.notification_claim_phone), actionIntent(id, CLAIM_ON_PHONE)).build())
                .addAction(new Notification.Action.Builder(null,
                    labels.getString(R.string.notification_decline), actionIntent(id, DECLINE)).build());
        }
        manager.notify(id, 0, notification.build());
        if (!alreadyPosted) wakeForNotification(manager);
        return true;
    }

    private PendingIntent actionIntent(String id, String action) {
        Intent intent = new Intent(this, MealDecisionActionActivity.class)
            .setData(Uri.parse("diabeatthis://meal-decision/" + id + "/" + action))
            .putExtra(EXTRA_REQUEST_ID, id)
            .putExtra(EXTRA_REQUEST_ACTION, action)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }

    @SuppressWarnings("deprecation")
    private void wakeForNotification(NotificationManager notifications) {
        var power = getSystemService(PowerManager.class);
        if (power.isInteractive()
                || notifications.getCurrentInterruptionFilter() != NotificationManager.INTERRUPTION_FILTER_ALL
                || notifications.getNotificationChannel(CHANNEL).getImportance()
                    < NotificationManager.IMPORTANCE_HIGH) return;
        try {
            power.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "diabeatthis:meal-invitation").acquire(3000);
        } catch (SecurityException ignored) {
            // The posted notification remains available if the OS disallows wake-up.
        }
    }
}
