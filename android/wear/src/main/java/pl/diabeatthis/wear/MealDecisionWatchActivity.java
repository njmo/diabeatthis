package pl.diabeatthis.wear;

import static pl.diabeatthis.wear.WatchPalette.ACCENT;
import static pl.diabeatthis.wear.WatchPalette.BACKGROUND;
import static pl.diabeatthis.wear.WatchPalette.MUTED;
import static pl.diabeatthis.wear.WatchPalette.ON_SURFACE;
import static pl.diabeatthis.wear.WatchPalette.OUTLINE;
import static pl.diabeatthis.wear.WatchPalette.SURFACE;

import android.Manifest;
import android.animation.ObjectAnimator;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.ColorStateList;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.LayerDrawable;
import android.graphics.drawable.RippleDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.text.InputFilter;
import android.text.InputType;
import android.text.TextUtils;
import android.text.format.DateFormat;
import android.util.Log;
import android.view.Gravity;
import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.window.BackEvent;
import android.window.OnBackAnimationCallback;
import android.window.OnBackInvokedCallback;
import android.window.OnBackInvokedDispatcher;
import android.widget.Button;
import android.widget.Chronometer;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import com.google.android.gms.tasks.Task;
import com.google.android.gms.wearable.CapabilityClient;
import com.google.android.gms.wearable.Node;
import com.google.android.gms.wearable.MessageClient;
import com.google.android.gms.wearable.MessageEvent;
import com.google.android.gms.wearable.Wearable;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class MealDecisionWatchActivity extends Activity
        implements MessageClient.OnMessageReceivedListener {
    private static final String CAPABILITY = "diabeatthis_meal_decision_phone";
    private static final String PATH = "/diabeatthis/meal-decision";
    private static final long PREVIEW_TIMEOUT_MS = 15000;
    private static final String INBOX_CHANGED = PATH + "/inbox-changed";
    private final Handler handler = new Handler(Looper.getMainLooper());
    private WatchDisplayScale displayScale;
    private ScrollView scroll;
    private LinearLayout scrollContent;
    private LinearLayout contextContent;
    private Runnable swipeRight;
    private Runnable swipeLeft;
    private String tileMealState;
    private LinearLayout root;
    private LinearLayout footer;
    private LinearLayout content;
    private int contentSide;
    private int contentTop;
    private int contentBottom;
    private int requestGeneration;
    private String pairedPhone;
    static final String EXTRA_TILE_REQUEST_ID = "watchTileRequestId";
    private String tileRequestId;
    private String notificationRequestId;
    private String notificationAction;
    static final String EXTRA_SUMMARY_MEAL_ID = "watchSummaryMealId";
    static final String EXTRA_PLANNED_MEAL_ID = "watchPlannedMealId";
    private long requestedSummaryMealId;
    static final String EXTRA_START_ACCEPTED_MEAL_ID = "watchStartAcceptedMealId";
    private long requestedPlannedMealId;
    private boolean openedFromPlannedTile;
    private long focusedMealId;
    private final Set<String> openedChildDecisions = new HashSet<>();
    private float detailTouchX;
    private float detailTouchY;
    private boolean swipeHandled;
    private OnBackInvokedCallback systemBackCallback;
    private JSONObject focusedRequest;
    private long createdRequestGraceEnds;
    private boolean previewOpen;
    private boolean started;
    private boolean resumed;
    private boolean inboxVisible;
    private boolean requestingChildDecision;
    private Context localizedContext;
    private long leaseEndsAt;
    private long mealDeadline;
    private String activeRequestId;
    private String presenceStage = "context";
    private int presenceInFlightGeneration = -1;
    private Chronometer leaseTimer;
    private final Runnable presenceTick = this::renewPresence;
    private final Handler inboxHandler = new Handler(Looper.getMainLooper());
    private final Runnable refreshInbox = () -> {
        if (started && (!previewOpen || focusedMealId > 0) && !requestingChildDecision) refresh();
    };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        displayScale = new WatchDisplayScale(this);
        notificationRequestId = getIntent().getStringExtra(
            MealDecisionNotificationService.EXTRA_REQUEST_ID);
        notificationAction = takeNotificationAction(getIntent());
        tileRequestId = takeTileRequest(getIntent());
        requestedSummaryMealId = takeMealId(getIntent(), EXTRA_SUMMARY_MEAL_ID);
        requestedPlannedMealId = takeMealId(getIntent(), EXTRA_PLANNED_MEAL_ID);
        if (requestedPlannedMealId == 0) {
            requestedPlannedMealId = takeMealId(getIntent(), EXTRA_START_ACCEPTED_MEAL_ID);
        }
        openedFromPlannedTile = requestedPlannedMealId > 0;
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackground(WatchPalette.gradient(dp(142)));
        scroll = new ScrollView(this);
        scroll.setVerticalScrollBarEnabled(true);
        scroll.setClipToPadding(false);
        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        boolean round = getResources().getConfiguration().isScreenRound();
        contentSide = round ? getResources().getDisplayMetrics().widthPixels * 14 / 100 : dp(24);
        contentTop = round ? getResources().getDisplayMetrics().widthPixels * 15 / 100 : dp(21);
        contentBottom = round ? getResources().getDisplayMetrics().widthPixels * 19 / 100 : dp(14);
        content.setPadding(contentSide, contentTop, contentSide, contentBottom);
        scrollContent = content;
        scroll.addView(scrollContent);
        root.addView(scroll, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));
        contextContent = new LinearLayout(this);
        contextContent.setOrientation(LinearLayout.VERTICAL);
        contextContent.setGravity(Gravity.CENTER_VERTICAL);
        contextContent.setVisibility(View.GONE);
        root.addView(contextContent, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));
        footer = new LinearLayout(this);
        footer.setOrientation(LinearLayout.VERTICAL);
        footer.setVisibility(View.GONE);
        root.addView(footer);
        setContentView(root);
        registerSystemBack();
        root.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop,
            oldRight, oldBottom) -> updateGestureEdges());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        notificationRequestId = intent.getStringExtra(
            MealDecisionNotificationService.EXTRA_REQUEST_ID);
        notificationAction = takeNotificationAction(intent);
        tileRequestId = takeTileRequest(intent);
        requestedSummaryMealId = takeMealId(intent, EXTRA_SUMMARY_MEAL_ID);
        requestedPlannedMealId = takeMealId(intent, EXTRA_PLANNED_MEAL_ID);
        if (requestedPlannedMealId == 0) {
            requestedPlannedMealId = takeMealId(intent, EXTRA_START_ACCEPTED_MEAL_ID);
        }
        openedFromPlannedTile = requestedPlannedMealId > 0;
        if (started && (notificationRequestId != null || tileRequestId != null ||
                requestedSummaryMealId > 0 || requestedPlannedMealId > 0)) refresh();
    }

    private String takeTileRequest(Intent intent) {
        String id = intent.getStringExtra(EXTRA_TILE_REQUEST_ID);
        intent.removeExtra(EXTRA_TILE_REQUEST_ID);
        return id != null && id.matches("[a-f0-9]{32}") ? id : null;
    }

    private String takeNotificationAction(Intent intent) {
        if (!(this instanceof MealDecisionActionActivity)
                || notificationRequestId == null
                || !notificationRequestId.matches("[a-f0-9]{32}")) return null;
        String action = intent.getStringExtra(MealDecisionNotificationService.EXTRA_REQUEST_ACTION);
        intent.removeExtra(MealDecisionNotificationService.EXTRA_REQUEST_ACTION);
        return action;
    }

    private long takeMealId(Intent intent, String key) {
        String id = intent.getStringExtra(key);
        if (id == null) return 0;
        intent.removeExtra(key);
        try {
            return Long.parseLong(id);
        } catch (NumberFormatException ignored) {
            return 0;
        }
    }

    @Override
    protected void onStart() {
        super.onStart();
        started = true;
        localizedContext = WatchLanguage.savedLabels(this);
        Wearable.getMessageClient(this).addListener(this);
        refresh();
    }

    @Override
    protected void onResume() {
        super.onResume();
        resumed = true;
        schedulePresence();
    }

    @Override
    protected void onPause() {
        resumed = false;
        handler.removeCallbacks(presenceTick);
        super.onPause();
    }

    @Override
    protected void onStop() {
        if (isFinishing() && tileMealState != null && !tileMealState.isEmpty()) {
            MealWatchTileService.getUpdater(this).requestUpdate(MealWatchTileService.class);
        }
        started = false;
        inboxVisible = false;
        requestingChildDecision = false;
        inboxHandler.removeCallbacks(refreshInbox);
        pairedPhone = null;
        Wearable.getMessageClient(this).removeListener(this);
        requestGeneration++;
        activeRequestId = null;
        leaseTimer = null;
        handler.removeCallbacksAndMessages(null);
        clearScreen();
        super.onStop();
    }

    @Override
    protected void onDestroy() {
        if (Build.VERSION.SDK_INT >= 34 && systemBackCallback != null) {
            getOnBackInvokedDispatcher().unregisterOnBackInvokedCallback(systemBackCallback);
            systemBackCallback = null;
        }
        super.onDestroy();
    }

    @Override
    public void onMessageReceived(MessageEvent event) {
        if (!started || (previewOpen && focusedMealId == 0) || requestingChildDecision
                || !INBOX_CHANGED.equals(event.getPath())
                || !event.getSourceNodeId().equals(pairedPhone)) return;
        inboxHandler.removeCallbacks(refreshInbox);
        inboxHandler.postDelayed(refreshInbox, 300);
    }

    private void refresh() {
        if (requestingChildDecision) return;
        activeRequestId = null;
        previewOpen = false;
        final int generation = ++requestGeneration;
        long lookupStarted = SystemClock.elapsedRealtime();
        if (!inboxVisible && focusedRequest == null) {
            clearScreen();
            text(string(R.string.connecting));
        }
        handler.removeCallbacksAndMessages(null);
        handler.postDelayed(() -> unavailable(generation), 8000);
        Wearable.getCapabilityClient(this)
            .getCapability(CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener(this, capability -> {
                if (generation != requestGeneration) return;
                timing("watch.capability.done", lookupStarted);
                Set<Node> phones = capability.getNodes();
                if (phones.size() != 1) {
                    unavailable(generation);
                    return;
                }
                String phone = phones.iterator().next().getId();
                pairedPhone = phone;
                if (notificationAction != null && notificationRequestId != null) {
                    String action = notificationAction;
                    String id = notificationRequestId;
                    notificationAction = null;
                    notificationRequestId = null;
                    if (MealDecisionNotificationService.CLAIM.equals(action)) {
                        openPreview(phone, id, true, Long.MAX_VALUE);
                        return;
                    }
                    if (MealDecisionNotificationService.DECLINE.equals(action)
                            || MealDecisionNotificationService.CLAIM_ON_PHONE.equals(action)) {
                        completeNotificationAction(generation, phone, id, action);
                        return;
                    }
                }
                request(phone, "list", notificationRequestId != null
                        ? notificationRequestId
                        : focusedRequest == null ? null : focusedRequest.optString("requestId"))
                    .addOnSuccessListener(this, reply -> receiveRequests(generation, phone, reply))
                    .addOnFailureListener(this, error -> unavailable(generation));
            })
            .addOnFailureListener(this, error -> unavailable(generation));
    }

    private void completeNotificationAction(int generation, String phone, String id, String action) {
        request(phone, action, id)
            .addOnSuccessListener(this, bytes -> {
                if (generation != requestGeneration) return;
                try {
                    JSONObject reply = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                    applyLanguage(reply.optString("languageTag"));
                    if (reply.optInt("version") == 1 && "ok".equals(reply.optString("status"))
                            && "caregiver".equals(reply.optString("mode"))) {
                        getSystemService(android.app.NotificationManager.class).cancel(id, 0);
                        if (MealDecisionNotificationService.CLAIM_ON_PHONE.equals(action)) {
                            handler.removeCallbacksAndMessages(null);
                            clearScreen();
                            text(string(R.string.notification_continue_phone));
                            handler.postDelayed(() -> {
                                if (generation == requestGeneration) finish();
                            }, 1400);
                        } else {
                            finish();
                        }
                        return;
                    }
                } catch (JSONException ignored) {
                    // Keep the invitation available if the action was not confirmed.
                }
                showMessage(generation, R.string.request_unconfirmed);
            })
            .addOnFailureListener(this, error -> showMessage(generation, R.string.request_unconfirmed));
    }

    private Task<byte[]> request(String phone, String action, String requestId) {
        String body = "{\"version\":1,\"action\":" + JSONObject.quote(action);
        if (requestId != null) body += ",\"requestId\":" + JSONObject.quote(requestId);
        if ("list".equals(action) && requestId != null && requestId.equals(notificationRequestId)) {
            body += ",\"openAnswer\":true";
        }
        byte[] bytes = (body + "}").getBytes(StandardCharsets.UTF_8);
        final long sentAt = SystemClock.elapsedRealtime();
        timing("watch.rpc." + action + ".start", sentAt);
        return Wearable.getMessageClient(this).sendRequest(phone, PATH, bytes)
            .addOnCompleteListener(task -> timing(
                "watch.rpc." + action + (task.isSuccessful() ? ".done" : ".error"), sentAt));
    }

    private void receiveRequests(int generation, String phone, byte[] reply) {
        if (generation != requestGeneration) return;
        try {
            JSONObject json = new JSONObject(new String(reply, StandardCharsets.UTF_8));
            String mode = json.optString("mode");
            applyLanguage(json.optString("languageTag"));
            if (json.optInt("version") != 1 || !("child".equals(mode) || "caregiver".equals(mode))) {
                unavailable(generation);
                return;
            }
            if ("unavailable".equals(json.optString("status"))) {
                showMessage(generation, R.string.requests_unavailable);
                return;
            }
            if (!"ok".equals(json.optString("status"))) {
                unavailable(generation);
                return;
            }
            JSONArray requests = json.getJSONArray("requests");
            JSONArray overviewPlans = json.optJSONArray("plans");
            JSONObject active = MealWatchTileService.activeMeal(overviewPlans);
            JSONObject ready = "child".equals(mode) ? MealWatchTileService.readyMeal(overviewPlans) : null;
            MealWatchTileService.cacheOverview(json);
            JSONObject visibleMeal = active == null ? ready : active;
            String currentTileMealState = visibleMeal == null ? "" : visibleMeal.toString();
            if (!currentTileMealState.equals(tileMealState)) {
                tileMealState = currentTileMealState;
                MealWatchTileService.getUpdater(this).requestUpdate(MealWatchTileService.class);
            }
            handler.removeCallbacksAndMessages(null);
            requestNotificationPermission();
            if ("caregiver".equals(mode)) {
                if (tileRequestId != null) {
                    renderTileRequest(phone, requests);
                    return;
                }
                requests = focusNotificationRequest(requests);
                JSONArray plans = json.optJSONArray("plans");
                if (active != null) {
                    renderActiveMeal(phone, active, false, generation);
                    return;
                }
                renderCaregiverHome(phone, requests, plans,
                    json.optBoolean("inboxAvailable", true), generation);
            } else {
                JSONArray plans = json.optJSONArray("plans");
                long summaryId = requestedSummaryMealId;
                requestedSummaryMealId = 0;
                if (requestedPlannedMealId > 0) {
                    clearMealFocus();
                    focusedMealId = requestedPlannedMealId;
                    requestedPlannedMealId = 0;
                }
                if (summaryId > 0 && plans != null) {
                    for (int i = 0; i < plans.length(); i++) {
                        JSONObject meal = plans.optJSONObject(i);
                        if (meal != null && meal.optLong("mealId") == summaryId
                                && meal.optBoolean("canComplete")) {
                            renderChildSummary(phone, meal, true);
                            return;
                        }
                    }
                }
                if (active != null) {
                    renderActiveMeal(phone, active, true, generation);
                    return;
                }
                if (tileRequestId != null && json.optBoolean("inboxAvailable", true)) {
                    String target = tileRequestId;
                    tileRequestId = null;
                    for (int i = 0; i < requests.length(); i++) {
                        JSONObject request = requests.optJSONObject(i);
                        if (request != null && target.equals(request.optString("requestId"))
                                && requestStillActive(request)) {
                            renderChildRequest(phone, request, request);
                            return;
                        }
                    }
                }
                if (notificationRequestId != null && json.optBoolean("inboxAvailable", true)) {
                    String target = notificationRequestId;
                    JSONArray focused = focusNotificationRequest(requests);
                    JSONObject decision = focused.optJSONObject(0);
                    if (decision != null && target.equals(decision.optString("requestId")) &&
                            "answered".equals(decision.optString("status"))) {
                        renderChildRequest(phone, decision, decision);
                        return;
                    }
                }
                if (openNewChildDecision(phone, plans, requests)) return;
                if (ready != null) {
                    renderActiveMeal(phone, ready, true, generation);
                    return;
                }
                if (focusedMealId > 0 && plans != null) {
                    for (int i = 0; i < plans.length(); i++) {
                        JSONObject meal = plans.optJSONObject(i);
                        if (meal != null && meal.optLong("mealId") == focusedMealId &&
                                meal.optString("activeStatus").isEmpty()) {
                            JSONObject request = pendingForMeal(requests, focusedMealId);
                            if (!meal.optString("acceptedDecision").isEmpty()) {
                                renderPlannedMeal(phone, meal);
                            } else if (request != null) {
                                renderChildRequest(phone, meal, request);
                            } else if (focusedRequest != null) {
                                boolean transientInbox = !json.optBoolean("inboxAvailable", true)
                                    || SystemClock.elapsedRealtime() < createdRequestGraceEnds;
                                if (json.optBoolean("allCaregiversDeclined")) {
                                    renderChildRequestStatus(phone, meal, null, R.string.child_request_declined);
                                } else if (transientInbox && requestStillActive(focusedRequest)) {
                                    renderChildRequest(phone, meal, focusedRequest);
                                } else {
                                    renderChildRequest(phone, meal, null);
                                }
                            } else {
                                renderPlannedMeal(phone, meal);
                            }
                            return;
                        }
                    }
                }
                if (focusedMealId > 0) {
                    JSONObject request = pendingForMeal(requests, focusedMealId);
                    if (request != null && request.optJSONObject("decision") != null) {
                        renderChildRequest(phone, request, request);
                        return;
                    }
                }
                clearMealFocus();
                renderChildPlans(phone, plans == null ? new JSONArray() : plans, requests, generation);
            }
        } catch (JSONException error) {
            unavailable(generation);
        }
    }

    private void renderTileRequest(String phone, JSONArray requests) {
        clearScreen();
        inboxVisible = false;
        content.setPadding(contentSide, dp(29), contentSide, dp(6));
        childBandLabel(content, string(R.string.meal_tile_invitation), ACCENT, 12);
        swipeLeft = () -> {
            tileRequestId = null;
            refresh();
        };
        long now = System.currentTimeMillis();
        for (int i = 0; i < requests.length(); i++) {
            JSONObject row = requests.optJSONObject(i);
            if (row == null || !tileRequestId.equals(row.optString("requestId"))
                    || row.optLong("deadlineMs") <= now) continue;
            long claimUntil = row.optLong("claimUntilMs");
            if (claimUntil > 0 && claimUntil <= now) continue;
            tileRequestId = null;
            openPreview(phone, row, claimUntil == 0);
            return;
        }
        if (tileRequestId.equals(MealWatchTileService.announcedInvitationId())) {
            text(string(R.string.connecting));
            handler.postDelayed(this::refresh, 1000);
            return;
        }
        text(string(R.string.expired));
        insetCompactButton(string(R.string.context_close), false, view -> finish());
    }

    private JSONArray focusNotificationRequest(JSONArray requests) {
        String id = notificationRequestId;
        notificationRequestId = null;
        if (id == null) return requests;
        for (int i = 0; i < requests.length(); i++) {
            JSONObject request = requests.optJSONObject(i);
            if (request != null && id.equals(request.optString("requestId"))) {
                return new JSONArray().put(request);
            }
        }
        return requests;
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < 33 ||
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                    == PackageManager.PERMISSION_GRANTED) return;
        var preferences = getPreferences(MODE_PRIVATE);
        if (preferences.getBoolean("askedForNotifications", false)) return;
        preferences.edit().putBoolean("askedForNotifications", true).apply();
        requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1);
    }

    private void renderCaregiverHome(String phone, JSONArray requests, JSONArray meals,
                                     boolean inboxAvailable, int generation) {
        int position = inboxVisible ? scroll.getScrollY() : 0;
        clearScreen();
        inboxVisible = true;
        swipeRight = this::exitToWatchFace;
        content.setPadding(0, contentTop, 0, contentBottom);
        var invitations = new LinkedHashMap<Long, JSONObject>();
        long now = System.currentTimeMillis();
        long nextExpiry = now + 20000;
        for (int i = 0; i < requests.length(); i++) {
            JSONObject row = requests.optJSONObject(i);
            if (row == null || row.optLong("deadlineMs") <= now) continue;
            long claimUntil = row.optLong("claimUntilMs");
            if (claimUntil > 0 && claimUntil <= now) continue;
            nextExpiry = Math.min(nextExpiry, row.optLong("deadlineMs"));
            if (claimUntil > now) nextExpiry = Math.min(nextExpiry, claimUntil);
            invitations.putIfAbsent(row.optLong("mealId", -1L - i), row);
        }
        renderMealList(phone, meals == null ? new JSONArray() : meals, invitations, false);
        if (!inboxAvailable) {
            var message = label(content, string(R.string.requests_unavailable), MUTED, 12, false, Gravity.CENTER);
            message.setPadding(contentSide, dp(6), contentSide, 0);
        }
        restoreScroll(position);
        handler.postDelayed(() -> {
            if (generation == requestGeneration) refresh();
        }, nextExpiry - now);
    }

    private void renderActiveMeal(String phone, JSONObject meal, boolean child, int generation) {
        clearMealFocus();
        previewOpen = false;
        inboxVisible = true;
        clearScreen();
        var active = ActiveMealPresentation.from(localizedContext == null ? this : localizedContext, meal, child);
        JSONObject progress = active.progress();
        boolean showBolusAmounts = active.showsBolusAmounts();
        content.setPadding(dp(8), dp(active.topPadding()), dp(8), dp(showBolusAmounts ? 0 : 4));
        swipeLeft = this::finish;
        addMealHeader(content, active.heading(), ACCENT, 11,
            active.logoSize(), active.headingGap());
        var name = childBandLabel(content, active.title(), ON_SURFACE, ActiveMealPresentation.TITLE_SIZE);
        name.setMaxLines(2);
        name.setEllipsize(TextUtils.TruncateAt.END);
        if (meal.optBoolean("treatmentSurplus")) {
            childBandLabel(content, string(R.string.active_meal_treatment_surplus),
                ActiveMealPresentation.WARNING_COLOR, 11).setMaxLines(2);
        }
        long deadline = active.waitUntil();
        if (deadline > 0) renderActiveWaitClock(deadline);
        if (showBolusAmounts) {
            if (!active.waitsForExtendedCarbs()) {
                childBandLabel(content, string(R.string.active_meal_aaps), MUTED, ActiveMealPresentation.AMOUNTS_TITLE_SIZE)
                    .setPadding(0, dp(2), 0, 0);
            }
            var amounts = card();
            var columns = new LinearLayout(this);
            amounts.addView(columns);
            metric(columns, string(R.string.carbs_label), string(R.string.active_meal_grams,
                progress.optInt("carbs")), progress.optBoolean("carbsEntered"));
            if (progress.has("extendedCarbs")) {
                metric(columns, string(R.string.active_meal_ecarbs), string(R.string.active_meal_grams,
                    progress.optInt("extendedCarbs")), progress.optBoolean("extendedCarbsConfirmed"));
            }
        }
        int count = active.count();
        if (count > 0) showActiveMealArc(progress, count);

        if (!active.status().isEmpty()) {
            childBandLabel(content, active.status(), MUTED, ActiveMealPresentation.STATUS_SIZE);
        }
        boolean startAfterWait = active.canStartEating();
        if (child && (active.canFinishEating() || active.readyToStart() || startAfterWait)) {
            footer.setVisibility(View.VISIBLE);
            var eaten = compactButton(footer,
                string(active.readyToStart() || startAfterWait ? R.string.start_eating : R.string.meal_eaten), true,
                view -> {
                    if (active.readyToStart()) {
                        sendChildMealAction(phone, meal.optLong("mealId"), "startAcceptedMeal");
                    } else if (startAfterWait) {
                        sendChildMealAction(phone, meal.optLong("mealId"), "startEatingAfterWait");
                    } else {
                        renderChildSummary(phone, meal, true);
                    }
                });
            footer.removeView(eaten);
            footer.addView(eaten, 0);
            var layout = new LinearLayout.LayoutParams(dp(ActiveMealPresentation.EATEN_BUTTON_WIDTH),
                dp(ActiveMealPresentation.EATEN_BUTTON_HEIGHT));
            layout.gravity = Gravity.CENTER_HORIZONTAL;
            layout.topMargin = dp(5);
            eaten.setLayoutParams(layout);
            eaten.setPadding(0, 0, 0, 0);
            eaten.setTextSize(displayScale.dp(13));
        }
        handler.postDelayed(() -> {
            if (generation == requestGeneration) refresh();
        }, 5000);
    }

    private void renderActiveWaitClock(long deadline) {
        leaseTimer = new Chronometer(this);
        leaseTimer.setCountDown(true);
        leaseTimer.setGravity(Gravity.CENTER);
        leaseTimer.setIncludeFontPadding(false);
        leaseTimer.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX,
            displayScale.pixelsAtFraction(ActiveMealPresentation.WAIT_CLOCK_FRACTION));
        leaseTimer.setTextColor(ON_SURFACE);
        leaseTimer.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        leaseTimer.setBase(SystemClock.elapsedRealtime() + Math.max(0, deadline - System.currentTimeMillis()));
        leaseTimer.setOnChronometerTickListener(timer -> {
            if (SystemClock.elapsedRealtime() >= timer.getBase()) {
                timer.stop();
                timer.setText("00:00");
            }
        });
        content.addView(leaseTimer);
        leaseTimer.start();
    }

    private void showActiveMealArc(JSONObject progress, int count) {
        footer.setVisibility(View.VISIBLE);
        footer.setPadding(0, 0, 0, dp(ActiveMealPresentation.ARC_BOTTOM_PADDING));
        View track = new View(this) {
            private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

            @Override
            protected void onDraw(Canvas canvas) {
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(dp(3));
                float radius = dp(169) / 2f;
                float center = getWidth() / 2f;
                float bottom = getHeight() - dp(2);
                float step = 88f / count;
                for (int i = 0; i < count; i++) {
                    paint.setColor(ActiveMealPresentation.progressColor(progress, i));
                    canvas.drawArc(center - radius, bottom - 2 * radius, center + radius,
                        bottom, 134 - step * i, -step + 4, false, paint);
                }
            }
        };
        footer.addView(track, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(ActiveMealPresentation.ARC_HEIGHT)));
    }

    private void renderChildPlans(String phone, JSONArray plans, JSONArray requests, int generation) {
        int position = inboxVisible ? scroll.getScrollY() : 0;
        clearScreen();
        content.setPadding(0, contentTop, 0, contentBottom);
        inboxVisible = true;
        swipeRight = this::exitToWatchFace;
        long now = System.currentTimeMillis();
        long nextExpiry = Long.MAX_VALUE;
        Map<Long, JSONObject> pending = new LinkedHashMap<>();
        for (int i = 0; i < requests.length(); i++) {
            JSONObject row = requests.optJSONObject(i);
            if (row == null || !requestStillActive(row)) continue;
            pending.putIfAbsent(row.optLong("mealId"), row);
            if (row.optLong("deadlineMs") > now) {
                nextExpiry = Math.min(nextExpiry, row.optLong("deadlineMs"));
            }
            long claimUntil = row.optLong("claimUntilMs");
            if (claimUntil > now) nextExpiry = Math.min(nextExpiry, claimUntil);
        }
        renderMealList(phone, plans, pending, true);
        restoreScroll(position);
        if (nextExpiry != Long.MAX_VALUE) {
            handler.postDelayed(() -> {
                if (generation == requestGeneration && !requestingChildDecision) {
                    renderChildPlans(phone, plans, requests, generation);
                }
            }, nextExpiry - now);
        }
    }

    private void renderMealList(String phone, JSONArray plans, Map<Long, JSONObject> requests,
                                boolean child) {
        long now = System.currentTimeMillis();
        var list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        content.addView(list);
        content.setPadding(0, dp(10), 0, contentBottom);
        addMealHeader(list, R.string.child_plans, MUTED, 12, 20, 6);
        for (int i = 0; i < plans.length(); i++) {
            JSONObject meal = plans.optJSONObject(i);
            if (meal == null || meal.optLong("mealId") <= 0) continue;
            JSONObject request = requests.remove(meal.optLong("mealId"));
            LinearLayout band = mealBand(list);
            childBandLabel(band, plannedTime(meal), ACCENT, 11);
            childMealName(band, meal);
            if (child) {
                if (request != null) childBandLabel(band, childStatus(request, now), ACCENT, 12);
                band.setFocusable(true);
                band.setOnClickListener(view -> {
                    if (request == null) renderPlannedMeal(phone, meal);
                    else renderChildRequest(phone, meal, request);
                });
            } else if (request != null) {
                addCaregiverRequestAction(phone, band, request, now);
            }
        }
        for (JSONObject request : requests.values()) {
            LinearLayout band = mealBand(list);
            childMealName(band, request);
            if (child) {
                childBandLabel(band, childStatus(request, now), ACCENT, 12);
            } else {
                addCaregiverRequestAction(phone, band, request, now);
            }
        }
        if (list.getChildCount() == 1) {
            var empty = childBandLabel(list, string(R.string.meal_tile_empty), ON_SURFACE, 14);
            empty.setPadding(0, dp(6), 0, 0);
        }
    }

    private void addMealHeader(LinearLayout list, int heading, int color, int size,
                               int logoSize, int headingGap) {
        var header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setGravity(Gravity.CENTER_HORIZONTAL);
        list.addView(header, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        var logo = new ImageView(this);
        logo.setImageResource(R.mipmap.ic_launcher);
        logo.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        header.addView(logo, new LinearLayout.LayoutParams(dp(logoSize), dp(logoSize)));

        String appName = getApplicationInfo().loadLabel(getPackageManager()).toString();
        var brand = childBandLabel(header, appName, MUTED, 8);
        brand.setPadding(0, dp(1), 0, 0);
        var title = childBandLabel(header, string(heading), color, size);
        title.setPadding(0, dp(headingGap), 0, 0);
    }

    private void addCaregiverRequestAction(String phone, LinearLayout band, JSONObject request, long now) {
        boolean claimed = request.optLong("claimUntilMs") > now;
        compactButton(band, string(claimed ? R.string.open_request : R.string.claim_request),
            true, view -> openPreview(phone, request, !claimed));
    }

    private LinearLayout mealBand(LinearLayout parent) {
        var band = new LinearLayout(this);
        band.setOrientation(LinearLayout.VERTICAL);
        var background = new LayerDrawable(new Drawable[] {
            new ColorDrawable(OUTLINE),
            new ColorDrawable(SURFACE),
        });
        background.setLayerInset(1, 0, dp(1), 0, dp(1));
        band.setBackground(new RippleDrawable(ColorStateList.valueOf(0x33ffffff), background, null));
        band.setPadding(contentSide, dp(5), contentSide, dp(5));
        var layout = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        layout.topMargin = dp(6);
        parent.addView(band, layout);
        return band;
    }

    private void childMealName(LinearLayout band, JSONObject meal) {
        var name = childBandLabel(band, meal.optString("mealName"), ON_SURFACE, 12);
        name.setMaxLines(3);
        name.setEllipsize(TextUtils.TruncateAt.END);
    }

    private TextView childBandLabel(LinearLayout parent, String text, int color, int size) {
        var view = label(parent, text, color, size, false, Gravity.CENTER);
        view.setIncludeFontPadding(false);
        view.setPadding(0, 0, 0, 0);
        return view;
    }

    private void renderPlannedMeal(String phone, JSONObject meal) {
        clearMealFocus();
        focusedMealId = meal.optLong("mealId");
        ++requestGeneration;
        handler.removeCallbacksAndMessages(null);
        inboxHandler.removeCallbacks(refreshInbox);
        tileRequestId = null;
        previewOpen = true;
        inboxVisible = false;
        clearScreen();
        scroll.setFillViewport(true);
        content.setPadding(contentSide, dp(8), contentSide, dp(13));
        swipeRight = this::leaveMeal;
        plannedTextButton(string(R.string.back) + "  ›", this::leaveMeal);

        var heading = childBandLabel(content, meal.optString("mealName"), ON_SURFACE, 13);
        heading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        heading.setMaxLines(4);
        heading.setEllipsize(TextUtils.TruncateAt.END);

        content.addView(new View(this), new LinearLayout.LayoutParams(0, 0, 1));
        boolean accepted = !meal.optString("acceptedDecision").isEmpty();
        long bolusDue = meal.optLong("bolusDueAtMs");
        if (accepted && bolusDue > 0) {
            childBandLabel(content, string(R.string.scheduled_bolus_at, formatTime(bolusDue)),
                ACCENT, 13).setMaxLines(2);
        } else {
            Button eat = addButton(content, string(accepted ? R.string.start_eating : R.string.eat_meal), true, view -> {
                if (accepted) {
                    sendChildMealAction(phone, focusedMealId, "startAcceptedMeal");
                } else if (meal.optBoolean("canRequest")) {
                    requestChildDecision(phone, meal);
                } else if (meal.optBoolean("canUseAdvisor")) {
                    exchangeChildAdvisor(phone, meal, UUID.randomUUID().toString().replace("-", ""), false);
                } else {
                    sendChildMealAction(phone, focusedMealId, "startMealOnPhone");
                }
            });
            eat.setTextSize(displayScale.dp(12));
            eat.setBackground(new RippleDrawable(ColorStateList.valueOf(0x22000000),
                rounded(ACCENT, 13), null));
            LinearLayout.LayoutParams inset = new LinearLayout.LayoutParams(dp(100), dp(36));
            inset.gravity = Gravity.CENTER_HORIZONTAL;
            eat.setLayoutParams(inset);
        }
        plannedTextButton(string(R.string.child_skip_meal),
            () -> confirmChildSkip(phone, meal, heading.getText().toString()));
    }

    private void plannedTextButton(String title, Runnable action) {
        Button button = compactButton(content, title, false, view -> action.run());
        button.setTextSize(displayScale.dp(10));
        button.setTextColor(MUTED);
        button.setBackground(new RippleDrawable(ColorStateList.valueOf(0x33ffffff),
            null, rounded(SURFACE, 20)));
        LinearLayout.LayoutParams layout = new LinearLayout.LayoutParams(dp(96), dp(32));
        layout.gravity = Gravity.CENTER_HORIZONTAL;
        button.setLayoutParams(layout);
    }

    private void confirmChildSkip(String phone, JSONObject meal, String name) {
        ++requestGeneration;
        clearScreen();
        title(string(R.string.child_skip_confirm));
        text(name);
        Runnable cancel = () -> renderPlannedMeal(phone, meal);
        swipeLeft = cancel;
        childActions(R.string.child_cancel_skip, cancel, R.string.child_skip_meal, true,
            () -> sendChildMealAction(phone, meal.optLong("mealId"), "skipMeal"));
    }

    private void childActions(int first, Runnable firstAction, int second,
                              boolean primary, Runnable secondAction) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER);
        int inset = Math.max(0, dp(34) - content.getPaddingLeft());
        row.setPadding(inset, 0, inset, 0);
        content.addView(row);
        childAction(row, first, false, firstAction);
        childAction(row, second, primary, secondAction);
    }

    private void childAction(LinearLayout row, int label, boolean primary, Runnable action) {
        Button button = addButton(row, string(label), primary, view -> action.run());
        var layout = new LinearLayout.LayoutParams(0, dp(42), 1);
        layout.setMargins(dp(2), dp(2), dp(2), 0);
        button.setLayoutParams(layout);
        button.setTextSize(displayScale.dp(12));
        button.setPadding(dp(4), 0, dp(4), 0);
        button.setSingleLine();
    }

    private void clearMealFocus() {
        focusedMealId = 0;
        focusedRequest = null;
        createdRequestGraceEnds = 0;
    }

    private void leaveMeal() {
        clearMealFocus();
        if (openedFromPlannedTile) {
            finish();
        } else {
            refresh();
        }
    }

    private boolean requestStillActive(JSONObject request) {
        return "accepting".equals(request.optString("status")) ||
            request.optLong("deadlineMs") > System.currentTimeMillis();
    }

    private boolean openNewChildDecision(String phone, JSONArray plans, JSONArray requests) {
        for (int index = 0; index < requests.length(); index++) {
            JSONObject request = requests.optJSONObject(index);
            if (request == null || !"answered".equals(request.optString("status"))
                    || !requestStillActive(request) || request.optJSONObject("decision") == null
                    || request.optLong("mealId") <= 0) continue;
            String id = request.optString("requestId");
            if (id.isBlank() || openedChildDecisions.contains(id)) continue;
            JSONObject meal = request;
            if (plans != null) {
                for (int planIndex = 0; planIndex < plans.length(); planIndex++) {
                    JSONObject plan = plans.optJSONObject(planIndex);
                    if (plan != null && plan.optLong("mealId") == request.optLong("mealId")) {
                        meal = plan;
                        break;
                    }
                }
            }
            if (!meal.optString("acceptedDecision").isEmpty()) continue;
            renderChildRequest(phone, meal, request);
            return true;
        }
        return false;
    }

    private void renderChildRequest(String phone, JSONObject meal, JSONObject request) {
        renderChildRequestStatus(phone, meal, request, R.string.expired);
    }

    private void renderChildRequestStatus(String phone, JSONObject meal, JSONObject request,
                                          int closedStatus) {
        focusedMealId = meal.optLong("mealId");
        if (request != null) focusedRequest = request;
        previewOpen = true;
        inboxVisible = false;
        int generation = ++requestGeneration;
        handler.removeCallbacksAndMessages(null);
        clearScreen();
        content.setPadding(contentSide, dp(18), contentSide, dp(24));
        boolean canAccept = false;
        if (request == null) {
            childBandLabel(content, meal.optString("mealName"), ACCENT, 12);
            childScreenHeading(string(closedStatus));
        } else {
            JSONObject decision = request.optJSONObject("decision");
            if (decision != null && "answered".equals(request.optString("status"))
                    && requestStillActive(request)) {
                openedChildDecisions.add(request.optString("requestId"));
                canAccept = renderChildDecision(phone, meal, request, decision);
            } else {
                renderChildWaiting(meal, request);
            }
            long now = System.currentTimeMillis();
            long next = Math.min(request.optLong("deadlineMs"), request.optLong("claimUntilMs", Long.MAX_VALUE));
            long delay = next > now ? Math.min(5000, next - now) : 5000;
            handler.postDelayed(() -> {
                if (generation == requestGeneration) refresh();
            }, delay);
        }
        if (!canAccept) {
            insetCompactButton(string(R.string.back), false, view -> leaveMeal());
        }
    }

    private void childScreenHeading(String text) {
        var heading = childBandLabel(content, text, ON_SURFACE, 16);
        heading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        heading.setPadding(0, dp(5), 0, dp(5));
    }

    private void renderChildWaiting(JSONObject meal, JSONObject request) {
        var mealName = childBandLabel(content,
            ActiveMealPresentation.splitTitle(meal.optString("mealName")), ACCENT, 10);
        mealName.setMaxLines(3);
        mealName.setEllipsize(TextUtils.TruncateAt.END);
        mealName.setPadding(dp(9), 0, dp(9), 0);
        if ("accepting".equals(request.optString("status"))) {
            childScreenHeading(string(R.string.accepting));
            return;
        }
        long now = System.currentTimeMillis();
        var waiting = ChildWaitingPresentation.from(request, now);
        childScreenHeading(string(waiting.heading()));
        if (!waiting.caregiver().isEmpty()) {
            var name = childBandLabel(content, waiting.caregiver(), MUTED, 11);
            name.setMaxLines(1);
            name.setEllipsize(TextUtils.TruncateAt.END);
        }
        leaseTimer = new Chronometer(this);
        leaseTimer.setGravity(Gravity.CENTER);
        leaseTimer.setTextColor(ON_SURFACE);
        leaseTimer.setTextSize(displayScale.dp(26));
        leaseTimer.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        leaseTimer.setCountDown(true);
        long remaining = Math.max(0, waiting.deadline() - now);
        leaseTimer.setBase(SystemClock.elapsedRealtime() + remaining);
        leaseTimer.setOnChronometerTickListener(timer -> {
            if (SystemClock.elapsedRealtime() >= timer.getBase()) {
                timer.stop();
                timer.setText("0:00");
            }
        });
        content.addView(leaseTimer);
        leaseTimer.start();
        childBandLabel(content, string(R.string.child_decision_timer), MUTED, 11);
        var progress = new LinearLayout(this);
        for (int segment = 0; segment < 2; segment++) {
            View bar = new View(this);
            bar.setBackground(rounded((segment == 0 ? waiting.claimed() : waiting.deciding()) ? ACCENT : SURFACE, 2));
            var layout = new LinearLayout.LayoutParams(0, dp(3), 1);
            layout.setMargins(dp(2), dp(4), dp(2), dp(4));
            progress.addView(bar, layout);
        }
        content.addView(progress);
    }

    private boolean renderChildDecision(String phone, JSONObject meal, JSONObject request,
                                     JSONObject decision) {
        String caregiver = decision.optString("caregiverName", "");
        if (!renderChildDecisionDetails(meal, decision, R.string.child_decision_title, caregiver)) {
            return false;
        }
        insetCompactButton(string(R.string.child_accept_decision), true,
            view -> sendChildMealAction(phone, meal.optLong("mealId"), "acceptDecision",
                request.optString("requestId")));
        if (decision.optBoolean("allowManualDecision", true)) {
            insetCompactButton(string(R.string.reject_request), false,
                view -> sendChildMealAction(phone, meal.optLong("mealId"), "rejectDecision",
                    request.optString("requestId")));
        }
        return true;
    }

    private boolean renderChildDecisionDetails(JSONObject meal, JSONObject decision, int title,
                                                String sourceName) {
        childBandLabel(content, string(title), ACCENT, 12);
        var mealName = childBandLabel(content, meal.optString("mealName"), MUTED, 11);
        mealName.setMaxLines(2);
        mealName.setEllipsize(TextUtils.TruncateAt.END);
        String instructions = switch (decision.optString("type")) {
            case "insulinThenWait" -> string(R.string.child_decision_wait, decision.optInt("minutes"));
            case "insulinAndEat" -> string(R.string.child_decision_eat_now);
            case "eatThenInsulin" -> string(R.string.child_decision_eat_first);
            case "deferMeal" -> string(R.string.child_decision_defer, decision.optInt("minutes"));
            default -> "";
        };
        if (instructions.isEmpty()) {
            text(string(R.string.answered));
            return false;
        }
        childScreenHeading(instructions);
        if (!sourceName.isEmpty()) childBandLabel(content, sourceName, MUTED, 11);
        String note = decision.optString("note", "");
        if (!note.isEmpty()) text(note);
        return true;
    }

    private void exchangeChildAdvisor(String phone, JSONObject meal, String requestId,
                                      boolean accepting) {
        if (requestingChildDecision) return;
        requestingChildDecision = true;
        int generation = ++requestGeneration;
        handler.removeCallbacksAndMessages(null);
        inboxHandler.removeCallbacks(refreshInbox);
        clearScreen();
        text(string(accepting ? R.string.accepting : R.string.connecting));
        Runnable unavailable = () -> {
            if (generation != requestGeneration) return;
            ++requestGeneration;
            requestingChildDecision = false;
            handler.removeCallbacksAndMessages(null);
            clearScreen();
            swipeRight = () -> renderPlannedMeal(phone, meal);
            content.setPadding(contentSide, dp(18), contentSide, dp(24));
            text(string(accepting ? R.string.request_unconfirmed : R.string.child_advisor_unavailable));
            insetCompactButton(string(R.string.meal_summary_on_phone), true,
                view -> sendChildMealAction(phone, meal.optLong("mealId"), "startMealOnPhone"));
            insetCompactButton(string(R.string.back), false, view -> swipeRight.run());
        };
        final byte[] payload;
        try {
            payload = new JSONObject().put("version", 1)
                .put("action", accepting ? "acceptAdvisor" : "prepareAdvisor")
                .put("mealId", meal.optLong("mealId")).put("requestId", requestId)
                .toString().getBytes(StandardCharsets.UTF_8);
        } catch (JSONException error) {
            unavailable.run();
            return;
        }
        handler.postDelayed(unavailable, 8000);
        Wearable.getMessageClient(this).sendRequest(phone, PATH, payload)
            .addOnSuccessListener(this, bytes -> {
                if (generation != requestGeneration) return;
                try {
                    JSONObject reply = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                    if (reply.optInt("version") != 1 || !"ok".equals(reply.optString("status"))
                            || !"child".equals(reply.optString("mode"))) {
                        unavailable.run();
                        return;
                    }
                    handler.removeCallbacksAndMessages(null);
                    requestingChildDecision = false;
                    if (accepting) {
                        refresh();
                        return;
                    }
                    JSONObject decision = reply.getJSONObject("preview");
                    clearScreen();
                    swipeRight = () -> renderPlannedMeal(phone, meal);
                    content.setPadding(contentSide, dp(18), contentSide, dp(24));
                    if (!renderChildDecisionDetails(meal, decision, R.string.child_advisor_title, "")) {
                        unavailable.run();
                        return;
                    }
                    insetCompactButton(string(R.string.child_accept_decision), true,
                        view -> exchangeChildAdvisor(phone, meal, requestId, true));
                    insetCompactButton(string(R.string.back), false, view -> swipeRight.run());
                } catch (JSONException error) {
                    unavailable.run();
                }
            })
            .addOnFailureListener(this, error -> unavailable.run());
    }

    private JSONObject pendingForMeal(JSONArray requests, long mealId) {
        for (int i = 0; i < requests.length(); i++) {
            JSONObject row = requests.optJSONObject(i);
            if (row != null && row.optLong("mealId") == mealId &&
                    requestStillActive(row)) return row;
        }
        return null;
    }

    private void sendChildMealAction(String phone, long mealId, String action) {
        sendChildMealAction(phone, mealId, action, null);
    }

    private void sendChildMealAction(String phone, long mealId, String action, String requestId) {
        boolean accepting = requestId != null;
        requestingChildDecision = true;
        int generation = ++requestGeneration;
        handler.removeCallbacksAndMessages(null);
        clearScreen();
        text(string(accepting ? R.string.accepting : R.string.connecting));
        final byte[] payload;
        try {
            payload = new JSONObject().put("version", 1).put("action", action)
                .put("mealId", mealId).put("requestId", requestId)
                .toString().getBytes(StandardCharsets.UTF_8);
        } catch (JSONException error) {
            showMessage(generation, R.string.request_unconfirmed);
            return;
        }
        handler.postDelayed(() -> showMessage(generation, R.string.request_unconfirmed), 8000);
        Wearable.getMessageClient(this).sendRequest(phone, PATH, payload)
            .addOnSuccessListener(this, bytes -> {
                if (generation != requestGeneration) return;
                try {
                    JSONObject reply = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                    if (reply.optInt("version") == 1 && "ok".equals(reply.optString("status"))
                            && "child".equals(reply.optString("mode"))) {
                        if (accepting || "startAcceptedMeal".equals(action) || "startEatingAfterWait".equals(action)) {
                            requestingChildDecision = false;
                            clearMealFocus();
                            focusedMealId = mealId;
                            refresh();
                        } else {
                            clearMealFocus();
                            showMessage(generation, "skipMeal".equals(action)
                                ? R.string.meal_skipped : R.string.meal_summary_phone_ready);
                        }
                        return;
                    }
                } catch (JSONException ignored) {
                    // Read the current meal again after an unconfirmed action.
                }
                showMessage(generation, R.string.request_unconfirmed);
            })
            .addOnFailureListener(this, error -> showMessage(generation, R.string.request_unconfirmed));
    }

    private void renderChildSummary(String phone, JSONObject meal, boolean quickAvailable) {
        ++requestGeneration;
        handler.removeCallbacksAndMessages(null);
        inboxHandler.removeCallbacks(refreshInbox);
        previewOpen = true;
        inboxVisible = false;
        clearScreen();
        swipeRight = this::refresh;
        content.setPadding(dp(12), dp(21), dp(12), dp(10));
        JSONObject progress = meal.optJSONObject("progress");
        boolean extra = progress != null && "extra".equals(progress.optString("stage"));
        int headingId = quickAvailable && extra ? R.string.meal_summary_ate_entire_extra
            : R.string.child_meal_summary;
        var heading = childBandLabel(content, string(headingId), ON_SURFACE, 14);
        heading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        heading.setMaxLines(2);
        var headingLayout = new LinearLayout.LayoutParams(dp(126), LinearLayout.LayoutParams.WRAP_CONTENT);
        headingLayout.gravity = Gravity.CENTER_HORIZONTAL;
        heading.setLayoutParams(headingLayout);
        var name = childBandLabel(content,
            ActiveMealPresentation.splitTitle(meal.optString("mealName")), MUTED, 11);
        name.setMaxLines(2);
        name.setEllipsize(TextUtils.TruncateAt.END);
        name.setPadding(0, dp(2), 0, dp(2));
        if (quickAvailable) {
            addSummaryAction(extra ? R.string.meal_summary_ate_all
                    : R.string.meal_summary_as_planned, true, 138,
                () -> sendChildSummary(phone, meal, false));
            if (extra) {
                addSummaryAction(R.string.meal_summary_ate_less, false, 128,
                    () -> renderChildSummary(phone, meal, false));
                return;
            }
            if (meal.optBoolean("canAddOn")) {
                addSummaryAction(R.string.meal_summary_add_on, false, 128,
                    () -> renderChildAddOn(phone, meal));
            }
        } else {
            text(string(R.string.meal_summary_phone_required));
        }
        addSummaryAction(R.string.meal_summary_on_phone, !quickAvailable, 108,
            () -> sendChildSummary(phone, meal, true));
    }

    private void renderChildAddOn(String phone, JSONObject meal) {
        clearScreen();
        swipeRight = () -> renderChildSummary(phone, meal, true);
        content.setPadding(dp(12), dp(28), dp(12), dp(10));
        contextHeading(string(R.string.meal_summary_add_on));
        addSummaryAction(R.string.meal_summary_portions_one_and_half, true, 138,
            () -> sendChildSummaryCommand(phone, meal, "startMealAddOn", 1.5));
        addSummaryAction(R.string.meal_summary_portions_two, true, 128,
            () -> sendChildSummaryCommand(phone, meal, "startMealAddOn", 2.0));
        addSummaryAction(R.string.back, false, 108, swipeRight);
    }

    private void addSummaryAction(int label, boolean primary, int width, Runnable action) {
        var button = compactButton(content, string(label), primary, view -> action.run());
        button.setMinHeight(dp(34));
        button.setMinimumHeight(dp(34));
        button.setPadding(dp(6), dp(2), dp(6), dp(2));
        var layout = new LinearLayout.LayoutParams(dp(width), LinearLayout.LayoutParams.WRAP_CONTENT);
        layout.gravity = Gravity.CENTER_HORIZONTAL;
        layout.topMargin = dp(3);
        button.setLayoutParams(layout);
    }

    private void sendChildSummary(String phone, JSONObject meal, boolean onPhone) {
        sendChildSummaryCommand(phone, meal, onPhone ? "phoneMealSummary" : "completeMeal", null);
    }

    private void sendChildSummaryCommand(String phone, JSONObject meal, String action, Double portions) {
        boolean onPhone = "phoneMealSummary".equals(action);
        int generation = ++requestGeneration;
        clearScreen();
        text(string(R.string.meal_summary_wait));
        byte[] message;
        try {
            message = new JSONObject().put("version", 1)
                .put("action", action)
                .put("totalPortions", portions)
                .put("mealId", meal.optLong("mealId")).toString().getBytes(StandardCharsets.UTF_8);
        } catch (JSONException error) {
            showMessage(generation, R.string.meal_summary_unconfirmed);
            return;
        }
        handler.postDelayed(() -> showMessage(generation, R.string.meal_summary_unconfirmed), 8000);
        Wearable.getMessageClient(this).sendRequest(phone, PATH, message)
            .addOnSuccessListener(this, reply -> {
                if (generation != requestGeneration) return;
                try {
                    JSONObject result = new JSONObject(new String(reply, StandardCharsets.UTF_8));
                    String status = result.optString("status");
                    if (result.optInt("version") == 1 && "child".equals(result.optString("mode"))) {
                        if ("ok".equals(status)) {
                            if (portions != null) {
                                refresh();
                                return;
                            }
                            showMessage(generation, onPhone
                                ? R.string.meal_summary_phone_ready : R.string.meal_summary_saved);
                            return;
                        }
                        if (!onPhone && "bolusPending".equals(status)) {
                            refresh();
                            return;
                        }
                        if ("phoneRequired".equals(status)) {
                            renderChildSummary(phone, meal, false);
                            return;
                        }
                    }
                } catch (JSONException ignored) {
                    // A reply without a valid result does not confirm completion.
                }
                showMessage(generation, R.string.meal_summary_unconfirmed);
            })
            .addOnFailureListener(this, error -> showMessage(generation, R.string.meal_summary_unconfirmed));
    }

    private void exitToWatchFace() {
        Intent home = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        try {
            startActivity(home);
        } catch (android.content.ActivityNotFoundException ignored) {
            // Dismiss the app even if a system face activity is unavailable.
        }
        finish();
    }

    private Runnable backGesture() {
        if (swipeRight != null) return swipeRight;
        if (swipeLeft != null) return swipeLeft;
        return focusedMealId > 0 && !requestingChildDecision ? this::leaveMeal : this::finish;
    }

    private Runnable leftGesture() {
        return swipeLeft != null ? swipeLeft : swipeRight == null ? backGesture() : null;
    }

    private void registerSystemBack() {
        if (Build.VERSION.SDK_INT < 34 || systemBackCallback != null) return;
        systemBackCallback = new OnBackAnimationCallback() {
            private int edge = -1;

            @Override
            public void onBackStarted(BackEvent event) {
                edge = event.getSwipeEdge();
            }

            @Override
            public void onBackCancelled() {
                edge = -1;
            }

            @Override
            public void onBackInvoked() {
                Runnable action = edge == BackEvent.EDGE_RIGHT ? leftGesture() : backGesture();
                edge = -1;
                if (action != null) action.run();
            }
        };
        getOnBackInvokedDispatcher().registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT, systemBackCallback);
    }

    private void updateGestureEdges() {
        if (swipeRight == null || root.getWidth() == 0) {
            root.setSystemGestureExclusionRects(List.of());
            return;
        }
        int width = root.getWidth();
        int height = root.getHeight();
        int top = height / 4;
        int bottom = height - top;
        int edge = dp(18);
        root.setSystemGestureExclusionRects(List.of(
            new Rect(0, top, edge, bottom), new Rect(width - edge, top, width, bottom)));
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        int action = event.getActionMasked();
        if (action == MotionEvent.ACTION_DOWN) {
            detailTouchX = event.getX();
            detailTouchY = event.getY();
            swipeHandled = false;
            super.dispatchTouchEvent(event);
            return true;
        }
        if (swipeHandled) return true;
        if (action == MotionEvent.ACTION_MOVE || action == MotionEvent.ACTION_UP) {
            float horizontal = event.getX() - detailTouchX;
            float vertical = Math.abs(event.getY() - detailTouchY);
            float threshold = Math.max(root.getWidth() * .12f, vertical * 1.4f);
            Runnable gesture = null;
            if (horizontal < -threshold) {
                gesture = leftGesture();
            } else if (horizontal > threshold) {
                gesture = backGesture();
            }
            if (gesture != null) {
                swipeHandled = true;
                MotionEvent cancel = MotionEvent.obtain(event);
                cancel.setAction(MotionEvent.ACTION_CANCEL);
                super.dispatchTouchEvent(cancel);
                cancel.recycle();
                gesture.run();
                return true;
            }
        }
        return super.dispatchTouchEvent(event);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        if (event.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER)
                && event.getActionMasked() == MotionEvent.ACTION_SCROLL) {
            int delta = Math.round(-event.getAxisValue(MotionEvent.AXIS_SCROLL) * dp(36));
            if (delta != 0 && scroll.canScrollVertically(Integer.signum(delta))) {
                scroll.smoothScrollBy(0, delta);
                return true;
            }
        }
        return super.dispatchGenericMotionEvent(event);
    }

    @Override
    public boolean onKeyUp(int code, KeyEvent event) {
        int direction = code == KeyEvent.KEYCODE_STEM_1 ? 1
            : code == KeyEvent.KEYCODE_STEM_2 ? -1 : 0;
        if (direction != 0 && scroll.canScrollVertically(direction)) {
            scroll.smoothScrollBy(0, direction * scroll.getHeight() / 2);
            return true;
        }
        return super.onKeyUp(code, event);
    }

    private void restoreScroll(int position) {
        if (position > 0) scroll.post(() -> scroll.scrollTo(0, position));
    }

    private String formatTime(long epoch) {
        return new java.text.SimpleDateFormat("HH:mm", localizedContext.getResources()
            .getConfiguration().getLocales().get(0)).format(new java.util.Date(epoch));
    }

    private String plannedTime(JSONObject meal) {
        long planned = meal.optLong("plannedAtMs");
        if (planned > 0) {
            Date date = new Date(planned);
            Context labels = localizedContext == null ? this : localizedContext;
            var dayFormat = DateFormat.getDateFormat(labels);
            Locale locale = labels.getResources().getConfiguration().getLocales().get(0);
            String plannedHour = new SimpleDateFormat("HH:mm", locale).format(date);
            return dayFormat.format(date).equals(dayFormat.format(new Date()))
                ? plannedHour : dayFormat.format(date) + " · " + plannedHour;
        }
        return string(R.string.no_planned_time);
    }

    private void requestChildDecision(String phone, JSONObject meal) {
        if (requestingChildDecision) return;
        requestingChildDecision = true;
        final int generation = ++requestGeneration;
        inboxHandler.removeCallbacks(refreshInbox);
        handler.removeCallbacksAndMessages(null);
        clearScreen();
        title(meal.optString("mealName"));
        text(string(R.string.sending_request));
        final byte[] payload;
        try {
            payload = new JSONObject().put("version", 1).put("action", "requestDecision")
                .put("mealId", meal.optLong("mealId")).put("requestId", UUID.randomUUID().toString().replace("-", ""))
                .toString().getBytes(StandardCharsets.UTF_8);
        } catch (JSONException error) {
            showMessage(generation, R.string.request_unconfirmed);
            return;
        }
        handler.postDelayed(() -> showMessage(generation, R.string.request_unconfirmed), 8000);
        Wearable.getMessageClient(this).sendRequest(phone, PATH, payload)
            .addOnSuccessListener(this, bytes -> {
                if (generation != requestGeneration) return;
                try {
                    JSONObject reply = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                    if (reply.optInt("version") != 1 || !"ok".equals(reply.optString("status"))
                            || !"child".equals(reply.optString("mode"))) {
                        showMessage(generation, R.string.request_unconfirmed);
                        return;
                    }
                    JSONObject created = reply.getJSONArray("requests").getJSONObject(0);
                    requestingChildDecision = false;
                    createdRequestGraceEnds = SystemClock.elapsedRealtime() + 10000;
                    renderChildRequest(phone, meal, created);
                    inboxHandler.postDelayed(refreshInbox, 1200);
                } catch (JSONException error) {
                    showMessage(generation, R.string.request_unconfirmed);
                }
            })
            .addOnFailureListener(this, error -> showMessage(generation, R.string.request_unconfirmed));
    }

    private String childStatus(JSONObject row, long now) {
        switch (row.optString("status")) {
            case "answered": return string(R.string.answered);
            case "accepting": return string(R.string.accepting);
            default:
                String caregiver = row.optString("caregiverName");
                return caregiver.isEmpty() || row.optLong("claimUntilMs") <= now
                    ? string(R.string.waiting)
                    : string(R.string.claimed, caregiver);
        }
    }

    private void openPreview(String phone, JSONObject row, boolean claim) {
        long deadline = row.optLong("deadlineMs");
        long expires = claim ? deadline : Math.min(row.optLong("claimUntilMs"), deadline);
        openPreview(phone, row.optString("requestId"), claim, expires - System.currentTimeMillis());
    }

    private void openPreview(String phone, String requestId, boolean claim, long remaining) {
        timing(claim ? "watch.claim.tap" : "watch.open.tap", SystemClock.elapsedRealtime());
        if (remaining <= 0) return;

        previewOpen = true;
        inboxVisible = false;
        int generation = ++requestGeneration;
        handler.removeCallbacksAndMessages(null);
        handler.postDelayed(() -> showMessage(generation,
            remaining <= PREVIEW_TIMEOUT_MS ? R.string.expired : R.string.preview_unavailable),
            Math.min(remaining, PREVIEW_TIMEOUT_MS));
        clearScreen();
        text(string(R.string.connecting));
        request(phone, claim ? "claim" : "open", requestId)
            .addOnSuccessListener(this, reply -> receivePreview(generation, phone, requestId, reply))
            .addOnFailureListener(this, error -> showMessage(generation, R.string.preview_unavailable));
    }

    private void receivePreview(int generation, String phone, String requestId, byte[] reply) {
        if (generation != requestGeneration) return;
        try {
            JSONObject response = new JSONObject(new String(reply, StandardCharsets.UTF_8));
            applyLanguage(response.optString("languageTag"));
            JSONObject preview = response.optJSONObject("preview");
            if (response.optInt("version") != 1 || !"ok".equals(response.optString("status"))
                    || !"caregiver".equals(response.optString("mode"))) {
                showMessage(generation, R.string.preview_unavailable);
                return;
            }
            JSONObject row = response.getJSONArray("requests").getJSONObject(0);
            long claimEnd = row.getLong("claimUntilMs");
            long deadline = row.getLong("deadlineMs");
            long expires = Math.min(claimEnd, deadline);
            long remaining = expires - System.currentTimeMillis();
            if (!requestId.equals(row.getString("requestId")) || remaining <= 0) {
                showMessage(generation, R.string.expired);
                return;
            }
            activeRequestId = requestId;
            presenceStage = "context";
            leaseEndsAt = claimEnd;
            mealDeadline = deadline;
            handler.removeCallbacksAndMessages(null);
            scheduleExpiration(generation);
            schedulePresence();
            if (preview == null) {
                clearScreen();
                title(row.optString("mealName"));
                countdown();
                text(string(R.string.preview_unavailable));
                handler.postDelayed(() -> showMessage(generation, R.string.preview_unavailable), 1800);
                return;
            }
            JSONArray options = preview.getJSONArray("options");
            renderPreview(generation, phone, requestId, row, preview, options);
            final long boundAt = SystemClock.elapsedRealtime();
            content.post(() -> timing("watch.preview.firstFrame", boundAt));
        } catch (JSONException error) {
            showMessage(generation, R.string.preview_unavailable);
        }
    }

    private void renderPreview(int generation, String phone, String requestId,
                               JSONObject row, JSONObject preview, JSONArray options) {
        renderContextPage(generation, phone, requestId, row, preview, options, 0);
    }

    private void renderContextPage(int generation, String phone, String requestId,
                                   JSONObject row, JSONObject preview, JSONArray options, int page) {
        if (generation != requestGeneration) return;
        clearScreen();
        content = contextContent;
        content.setPadding(dp(29), dp(25), dp(29), 0);
        scroll.setVisibility(View.GONE);
        content.setVisibility(View.VISIBLE);
        updatePresenceStage("context");
        switch (page) {
            case 0 -> {
                String mealName = row.optString("mealName");
                int categoryEnd = mealName.indexOf(':');
                if (categoryEnd > 0) {
                    String category = mealName.substring(0, categoryEnd).trim();
                    mealName = "QM".equalsIgnoreCase(category)
                        ? mealName.substring(categoryEnd + 1).trim() : category;
                }
                contextHeading(mealName);
                countdown();
                showGlucoseReading(preview, 27);
                showGlucoseAge(preview);
            }
            case 1 -> {
                contextHeading(string(R.string.context_meal));
                if (preview.optLong("plannedAtMs") > 0) {
                    contextLabel(plannedTime(preview), MUTED, 10);
                }
                showCarbohydrateTotals(preview);
            }
            case 2 -> {
                contextHeading(string(R.string.glucose_chart));
                showGlucoseReading(preview, 18);
                chart(preview, "glucoseHistory", R.string.glucose_chart, 0xffffcf88, false);
                showGlucoseAge(preview);
            }
            case 3 -> {
                contextHeading(string(R.string.iob_short));
                showContextReading(preview, "iob", R.string.insulin_value);
                chart(preview, "iobHistory", R.string.iob_chart, 0xff89cff5, true);
            }
            case 4 -> {
                contextHeading(string(R.string.cob_short));
                showContextReading(preview, "cob", R.string.macro_value);
                chart(preview, "cobHistory", R.string.cob_chart, 0xffb5e890, true);
            }
            case 5 -> renderAdvisorSuggestion(preview.optJSONObject("advisorSuggestion"));
            default -> throw new IllegalArgumentException("Unknown context page");
        }
        boolean last = page == 5;
        Runnable previous = page == 0 ? this::refresh :
            () -> renderContextPage(generation, phone, requestId, row, preview, options, page - 1);
        Runnable next = last
            ? () -> chooseDecision(generation, phone, requestId, options,
                () -> renderContextPage(generation, phone, requestId, row, preview, options, page))
            : () -> renderContextPage(generation, phone, requestId, row, preview, options, page + 1);
        swipeLeft = next;
        swipeRight = previous;
        updateGestureEdges();
        showContextFooter(page, next);
    }

    private void renderAdvisorSuggestion(JSONObject suggestion) {
        content.setPadding(dp(27), dp(8), dp(27), dp(2));
        var heading = advisorLabel(content, R.string.context_advisor_title, ON_SURFACE, .059f, 2);
        heading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        String type = suggestion == null ? "" : suggestion.optString("type");
        int minutes = suggestion == null ? 0 : suggestion.optInt("minutes");
        int message = switch (type) {
            case "insulinAndEat" -> R.string.context_advisor_bolus_eat;
            case "eatThenInsulin" -> R.string.context_advisor_eat_bolus;
            case "insulinThenWait" -> minutes >= 1 && minutes <= 180
                ? R.string.context_advisor_bolus_wait : R.string.context_advisor_unavailable;
            default -> R.string.context_advisor_unavailable;
        };
        if (message == R.string.context_advisor_unavailable) {
            advisorLabel(content, message, MUTED, .059f, 2);
            return;
        }
        advisorLabel(content, R.string.context_advisor_source, MUTED, .049f, 1);
        var suggestionCard = new LinearLayout(this);
        suggestionCard.setOrientation(LinearLayout.VERTICAL);
        suggestionCard.setGravity(Gravity.CENTER);
        suggestionCard.setPadding(dp(4), dp(3), dp(4), dp(3));
        suggestionCard.setBackground(rounded(SURFACE, 12));
        var layout = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        layout.topMargin = dp(3);
        content.addView(suggestionCard, layout);
        advisorLabel(suggestionCard, message, ON_SURFACE, .049f, 2);
        if (message == R.string.context_advisor_bolus_wait) {
            var duration = childBandLabel(suggestionCard, string(R.string.minutes_value, minutes), ACCENT, 0);
            duration.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, displayScale.pixelsAtFraction(.074f));
            duration.setMaxLines(1);
            duration.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            advisorLabel(suggestionCard, R.string.context_advisor_then_meal, ON_SURFACE, .045f, 1);
        }
    }

    private TextView advisorLabel(LinearLayout parent, int text, int color, float fraction, int lines) {
        var label = childBandLabel(parent, string(text), color, 0);
        label.setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, displayScale.pixelsAtFraction(fraction));
        label.setMaxLines(lines);
        return label;
    }

    private void showContextSwipeHint() {
        var row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER);
        footer.addView(row, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(15)));
        var arrow = childBandLabel(row, "←", ACCENT, 13);
        arrow.setPadding(dp(4), 0, dp(4), 0);
        childBandLabel(row, string(R.string.context_swipe_left), MUTED, 10);
        var motion = ObjectAnimator.ofFloat(arrow, View.TRANSLATION_X, 0, -dp(5), 0);
        motion.setDuration(650);
        motion.setRepeatCount(2);
        motion.start();
    }

    private void compactCaregiverScreen() {
        content.setPadding(contentSide, dp(17), contentSide, dp(8));
    }

    private void showContextFooter(int page, Runnable next) {
        int[] titles = {R.string.context_summary, R.string.context_meal, R.string.context_glucose,
            R.string.iob_short, R.string.cob_short, R.string.context_to_decision};
        footer.setVisibility(View.VISIBLE);
        footer.setPadding(dp(32), 0, dp(32), dp(9));
        if (page == 0) showContextSwipeHint();
        var navigation = new LinearLayout(this);
        navigation.setGravity(Gravity.CENTER_VERTICAL);
        footer.addView(navigation);
        var forward = compactButton(navigation,
            string(R.string.context_page_label, string(titles[page])),
            false, view -> next.run());
        forward.setSingleLine();
        forward.setEllipsize(TextUtils.TruncateAt.END);
        forward.setPadding(0, 0, 0, 0);
        forward.setTextColor(ACCENT);
        forward.setBackgroundColor(Color.TRANSPARENT);
        forward.setLayoutParams(new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(page == 0 ? 22 : 30)));
        View track = new View(this) {
            private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);

            @Override
            protected void onDraw(Canvas canvas) {
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(dp(3));
                float width = getWidth();
                float height = getHeight();
                float radiusX = width * .52f;
                float radiusY = height * 1.8f;
                for (int step = 0; step < titles.length; step++) {
                    paint.setColor(step == page ? ACCENT :
                        step < page ? 0xff809d75 : 0xff46574d);
                    canvas.drawArc(width / 2 - radiusX, height - 2 * radiusY - dp(2),
                        width / 2 + radiusX, height - dp(2),
                        132 - step * 15, -11, false, paint);
                }
            }
        };
        footer.addView(track, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(page == 0 ? 12 : 19)));
    }

    private TextView contextLabel(String text, int color, int size) {
        var label = childBandLabel(content, text, color, size);
        label.setMaxLines(1);
        label.setEllipsize(TextUtils.TruncateAt.END);
        return label;
    }

    private void contextHeading(String title) {
        contextLabel(title, ON_SURFACE, 16).setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    }

    private void showContextReading(JSONObject preview, String field, int format) {
        double value = preview.optDouble(field);
        if (Double.isFinite(value)) {
            contextLabel(string(format, value), ON_SURFACE, 20)
                .setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        }
    }

    private void showGlucoseReading(JSONObject preview, int size) {
        double value = preview.optDouble("glucoseMgDl");
        if (!Double.isFinite(value)) return;
        String arrow = switch (preview.optString("glucoseDirection")) {
            case "DoubleUp" -> "⇈";
            case "SingleUp" -> "↑";
            case "FortyFiveUp" -> "↗";
            case "Flat" -> "→";
            case "FortyFiveDown" -> "↘";
            case "SingleDown" -> "↓";
            case "DoubleDown" -> "⇊";
            default -> "";
        };
        var row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER);
        content.addView(row);
        var reading = childBandLabel(row, Integer.toString((int) value), ON_SURFACE, size);
        reading.setSingleLine();
        reading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        var units = childBandLabel(row, string(R.string.glucose_unit), MUTED, 11);
        units.setPadding(dp(3), 0, 0, 0);
        units.setSingleLine();
        if (!arrow.isEmpty()) {
            var trend = childBandLabel(row, arrow, ACCENT, size - 3);
            trend.setPadding(dp(4), 0, 0, 0);
            trend.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        }
    }

    private void showGlucoseAge(JSONObject preview) {
        long readingAt = preview.optLong("glucoseAtMs");
        if (readingAt <= 0) {
            contextLabel(string(R.string.history_no_points), MUTED, 10);
            return;
        }
        contextLabel(string(R.string.glucose_label, time(readingAt)), MUTED, 10);
        Integer change = glucoseChange(preview, readingAt);
        if (change != null) {
            contextLabel(string(R.string.glucose_change, change), ACCENT, 11);
        }
        if (System.currentTimeMillis() - readingAt > 300000L) {
            var warning = contextLabel(string(R.string.context_glucose_stale), 0xffffcf88, 10);
            warning.setMaxLines(2);
            warning.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
            warning.setPadding(dp(4), dp(2), dp(4), dp(2));
            warning.setBackground(rounded(0xff33291c, 4));
        }
    }

    private Integer glucoseChange(JSONObject preview, long readingAt) {
        JSONArray history = preview.optJSONArray("glucoseHistory");
        double current = preview.optDouble("glucoseMgDl");
        if (history == null || !Double.isFinite(current)) return null;

        long previousAt = 0;
        double previous = Double.NaN;
        for (int i = 0; i < history.length(); i++) {
            JSONArray sample = history.optJSONArray(i);
            if (sample == null) continue;
            long time = sample.optLong(0);
            double value = sample.optDouble(1);
            if (time > previousAt && time < readingAt && readingAt - time <= 600000L
                    && Double.isFinite(value)) {
                previousAt = time;
                previous = value;
            }
        }
        return Double.isFinite(previous) ? (int) (current - previous) : null;
    }

    private void twoButtons(String first, Runnable firstAction, String second,
                            boolean primary, Runnable secondAction) {
        var row = new LinearLayout(this);
        footer.setVisibility(View.VISIBLE);
        footer.setPadding(dp(36), 0, dp(36), dp(17));
        footer.addView(row);
        for (int i = 0; i < 2; i++) {
            boolean left = i == 0;
            var button = compactButton(row, left ? first : second, !left && primary,
                view -> { if (left) firstAction.run(); else secondAction.run(); });
            button.setSingleLine();
            button.setPadding(dp(3), 0, dp(3), 0);
            var layout = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1);
            layout.setMargins(dp(2), dp(4), dp(2), dp(2));
            button.setLayoutParams(layout);
        }
    }

    private long expiry() {
        return Math.min(leaseEndsAt, mealDeadline);
    }

    private void scheduleExpiration(int generation) {
        handler.postAtTime(() -> {
            if (System.currentTimeMillis() >= expiry()) showMessage(generation, R.string.expired);
        }, SystemClock.uptimeMillis() + Math.max(0, expiry() - System.currentTimeMillis()));
    }

    private void schedulePresence() {
        handler.removeCallbacks(presenceTick);
        long remaining = leaseEndsAt - System.currentTimeMillis();
        if (resumed && activeRequestId != null && leaseEndsAt < mealDeadline && remaining > 0) {
            handler.postDelayed(presenceTick, Math.min(15000, Math.max(0, remaining - 8000)));
        }
    }

    private void updatePresenceStage(String stage) {
        if (stage.equals(presenceStage)) return;
        presenceStage = stage;
        handler.removeCallbacks(presenceTick);
        renewPresence();
    }

    private void renewPresence() {
        int generation = requestGeneration;
        if (!resumed || activeRequestId == null || pairedPhone == null
                || System.currentTimeMillis() >= expiry()
                || presenceInFlightGeneration == generation) return;
        String publishedStage = presenceStage;
        try {
            JSONObject body = new JSONObject().put("version", 1).put("action", "presence")
                .put("requestId", activeRequestId).put("stage", publishedStage);
            presenceInFlightGeneration = generation;
            Wearable.getMessageClient(this).sendRequest(pairedPhone, PATH,
                body.toString().getBytes(StandardCharsets.UTF_8))
                .addOnCompleteListener(this, task -> {
                    if (presenceInFlightGeneration == generation) presenceInFlightGeneration = -1;
                    if (generation != requestGeneration || !resumed) return;
                    boolean confirmed = false;
                    try {
                        if (task.isSuccessful()) {
                            JSONObject reply = new JSONObject(new String(task.getResult(), StandardCharsets.UTF_8));
                            confirmed = reply.optInt("version") == 1 && "ok".equals(reply.optString("status"));
                            long renewed = reply.optLong("claimUntilMs");
                            if (confirmed && renewed > leaseEndsAt) {
                                leaseEndsAt = renewed;
                                if (leaseTimer != null) updateCountdown();
                                scheduleExpiration(generation);
                            }
                        }
                    } catch (JSONException ignored) {
                        // Retry within the last confirmed lease.
                    }
                    if (!publishedStage.equals(presenceStage)) {
                        renewPresence();
                    } else if (confirmed) {
                        schedulePresence();
                    } else if (System.currentTimeMillis() + 2000 < expiry()) {
                        handler.postDelayed(presenceTick, 2000);
                    }
                });
        } catch (JSONException ignored) {
            // The request remains open until the last confirmed lease expires.
        }
    }

    private void countdown() {
        countdown(content);
    }

    private void countdown(LinearLayout parent) {
        leaseTimer = new Chronometer(this);
        leaseTimer.setGravity(Gravity.CENTER);
        leaseTimer.setTextColor(ACCENT);
        leaseTimer.setTextSize(displayScale.dp(13));
        leaseTimer.setTypeface(Typeface.MONOSPACE, Typeface.BOLD);
        leaseTimer.setPadding(dp(6), dp(3), dp(6), dp(3));
        leaseTimer.setCountDown(true);
        updateCountdown();
        parent.addView(leaseTimer);
        leaseTimer.start();
    }

    private void updateCountdown() {
        leaseTimer.setBase(SystemClock.elapsedRealtime()
            + Math.max(0, expiry() - System.currentTimeMillis()));
    }

    private void chart(JSONObject preview, String field, int label, int color, boolean stepped) {
        JSONArray points = preview.optJSONArray(field);
        long start = preview.optLong("chartStartMs");
        long end = preview.optLong("chartEndMs");
        if (points == null || end <= start) {
            contextLabel(string(R.string.history_no_points), MUTED, 10);
            return;
        }
        var chart = new MealHistoryChart(this, points, start, end, color, stepped, string(label));
        if (!chart.hasSamples()) {
            contextLabel(string(R.string.history_no_points), MUTED, 10);
            return;
        }
        var layout = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1);
        layout.setMargins(0, dp(3), 0, dp(2));
        content.addView(chart, layout);
        var axis = new LinearLayout(this);
        axis.setPadding(dp(5), 0, dp(5), 0);
        content.addView(axis);
        for (long edge : new long[] {start, end}) {
            var tick = childBandLabel(axis, time(edge), MUTED, 9);
            tick.setGravity(edge == start ? Gravity.START : Gravity.END);
            tick.setLayoutParams(new LinearLayout.LayoutParams(0,
                LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        }
    }

    private void chooseDecision(int generation, String phone, String requestId,
                                JSONArray options, Runnable back) {
        if (generation != requestGeneration) return;
        clearScreen();
        compactCaregiverScreen();
        countdown();
        updatePresenceStage("decision");
        childScreenHeading(string(R.string.choose_decision));
        for (int i = 0; i < options.length(); i++) {
            JSONObject option = options.optJSONObject(i);
            if (option == null) continue;
            var choice = compactButton(content, option.optString("label"), false,
                view -> reviewDecision(generation, phone, requestId, option,
                    option.has("defaultMinutes") ? option.optInt("defaultMinutes", 1) : null,
                    () -> chooseDecision(generation, phone, requestId, options, back)));
            var background = rounded(SURFACE, 10);
            background.setStroke(dp(1), OUTLINE);
            choice.setBackground(new RippleDrawable(ColorStateList.valueOf(0x33ffffff), background, null));
        }
        swipeRight = back;
        updateGestureEdges();
    }

    private void reviewDecision(int generation, String phone, String requestId,
                                JSONObject option, Integer initialMinutes, Runnable change) {
        if (generation != requestGeneration) return;
        clearScreen();
        content.setPadding(contentSide, dp(12), contentSide, dp(8));
        countdown();
        childScreenHeading(option.optString("label"));
        int[] minutes = {initialMinutes == null ? 0 : Math.max(1, Math.min(180, initialMinutes))};
        if (initialMinutes != null) {
            var row = new LinearLayout(this);
            row.setGravity(Gravity.CENTER);
            content.addView(row, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(36)));
            TextView value = new TextView(this);
            value.setGravity(Gravity.CENTER);
            value.setTextColor(ON_SURFACE);
            value.setTextSize(displayScale.dp(12));
            value.setSingleLine();
            int[] adjustments = {-5, 5};
            Button[] buttons = new Button[adjustments.length];
            Runnable update = () -> {
                value.setText(string(R.string.minutes_value, minutes[0]));
                for (int k = 0; k < buttons.length; k++) {
                    buttons[k].setEnabled(adjustments[k] < 0 ? minutes[0] > 1 : minutes[0] < 180);
                }
            };
            for (int k = 0; k < adjustments.length; k++) {
                if (k == 1) row.addView(value, new LinearLayout.LayoutParams(dp(52), dp(36)));
                int delta = adjustments[k];
                String sign = delta < 0 ? "−" : "+";
                Button button = compactButton(row, sign + Math.abs(delta), false, view -> {
                    minutes[0] = Math.max(1, Math.min(180, minutes[0] + delta));
                    update.run();
                });
                button.setPadding(0, 0, 0, 0);
                button.setContentDescription(sign + string(R.string.minutes_value, Math.abs(delta)));
                button.setMinimumWidth(0);
                button.setMinWidth(0);
                button.setMinimumHeight(0);
                button.setMinHeight(0);
                button.setBackground(new RippleDrawable(ColorStateList.valueOf(0x33ffffff),
                    rounded(SURFACE, 17), null));
                var layout = new LinearLayout.LayoutParams(dp(34), dp(34));
                layout.setMargins(dp(1), 0, dp(1), 0);
                button.setLayoutParams(layout);
                buttons[k] = button;
            }
            update.run();
        }
        EditText note = field();
        note.setTextSize(displayScale.dp(12));
        note.setHint(string(R.string.note));
        note.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_SENTENCES);
        note.setFilters(new InputFilter[]{new InputFilter.LengthFilter(240)});
        note.setSingleLine(true);
        content.addView(note);
        swipeRight = change;
        updateGestureEdges();
        twoButtons(string(R.string.context_change), change, string(R.string.send), true,
            () -> sendDecision(generation, phone, requestId, option,
                initialMinutes == null ? null : minutes[0], note.getText().toString().trim()));
    }

    private void sendDecision(int generation, String phone, String requestId,
                              JSONObject option, Integer minutes, String note) {
        if (generation != requestGeneration) return;
        if (System.currentTimeMillis() >= expiry()) {
            showMessage(generation, R.string.expired);
            return;
        }
        activeRequestId = null;
        final int sending = ++requestGeneration;
        handler.removeCallbacksAndMessages(null);
        clearScreen();
        text(string(R.string.sending));
        handler.postDelayed(() -> showMessage(sending, R.string.send_unconfirmed), 8000);
        try {
            JSONObject body = new JSONObject().put("version", 1).put("action", "respond")
                .put("requestId", requestId).put("type", option.optString("type")).put("message", note);
            if (minutes != null) body.put("minutes", minutes);
            Wearable.getMessageClient(this).sendRequest(phone, PATH,
                body.toString().getBytes(StandardCharsets.UTF_8))
                .addOnSuccessListener(this, bytes -> {
                    try {
                        JSONObject reply = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
                        boolean accepted = reply.optInt("version") == 1
                            && "ok".equals(reply.optString("status"))
                            && "caregiver".equals(reply.optString("mode"));
                        if (accepted && sending == requestGeneration) {
                            renderSentDecision(sending, option, minutes);
                            return;
                        }
                        int result = R.string.send_unconfirmed;
                        if ("expired".equals(reply.optString("status"))) result = R.string.expired;
                        showMessage(sending, result);
                    } catch (JSONException error) {
                        showMessage(sending, R.string.send_unconfirmed);
                    }
                })
                .addOnFailureListener(this, error -> showMessage(sending, R.string.send_unconfirmed));
        } catch (JSONException error) {
            showMessage(sending, R.string.send_unconfirmed);
        }
    }

    private void renderSentDecision(int generation, JSONObject option, Integer minutes) {
        if (generation != requestGeneration) return;
        handler.removeCallbacksAndMessages(null);
        clearScreen();
        childScreenHeading(string(R.string.sent));
        text(option.optString("label"));
        if (minutes != null) text(string(R.string.minutes_value, minutes));
        text(string(R.string.context_sent_child));
        insetCompactButton(string(R.string.context_close), false, view -> finish());
    }

    private void applyLanguage(String tag) {
        localizedContext = WatchLanguage.update(this, tag);
    }

    private String string(int id, Object... args) {
        Context labels = localizedContext == null ? this : localizedContext;
        return labels.getString(id, args);
    }

    private String time(long milliseconds) {
        Context labels = localizedContext == null ? this : localizedContext;
        Locale locale = labels.getResources().getConfiguration().getLocales().get(0);
        return new SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, "Hm"), locale)
            .format(new Date(milliseconds));
    }

    private void unavailable(int generation) {
        showMessage(generation, R.string.unavailable);
    }

    private void showMessage(int generation, int label) {
        if (generation != requestGeneration) return;
        requestGeneration++;
        activeRequestId = null;
        previewOpen = false;
        requestingChildDecision = false;
        inboxVisible = false;
        handler.removeCallbacksAndMessages(null);
        clearScreen();
        text(string(label));
        inboxHandler.removeCallbacks(refreshInbox);
        inboxHandler.postDelayed(refreshInbox,
            label == R.string.unavailable || label == R.string.requests_unavailable ? 5000 : 2500);
    }

    private void clearScreen() {
        if (leaseTimer != null) {
            leaseTimer.stop();
            leaseTimer = null;
        }
        swipeLeft = null;
        swipeRight = null;
        updateGestureEdges();
        contextContent.removeAllViews();
        contextContent.setVisibility(View.GONE);
        scroll.setVisibility(View.VISIBLE);
        content = scrollContent;
        content.setGravity(Gravity.TOP);
        content.removeAllViews();
        footer.removeAllViews();
        footer.setVisibility(View.GONE);
        scroll.setFillViewport(false);
        content.setPadding(contentSide, contentTop, contentSide, contentBottom);
        scroll.scrollTo(0, 0);
    }

    private void timing(String phase, long startedAt) {
        if ((getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0) {
            Log.i("MealDecisionTiming", phase + " ms=" + (SystemClock.elapsedRealtime() - startedAt));
        }
    }

    private int dp(int value) {
        return displayScale.px(value);
    }

    private GradientDrawable rounded(int color, int radius) {
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(color);
        shape.setCornerRadius(dp(radius));
        return shape;
    }

    private LinearLayout card() {
        var card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setBackground(rounded(SURFACE, 7));
        card.setPadding(0, dp(2), 0, dp(2));
        var layout = new LinearLayout.LayoutParams(dp(134), LinearLayout.LayoutParams.WRAP_CONTENT);
        layout.gravity = Gravity.CENTER_HORIZONTAL;
        layout.setMargins(0, dp(2), 0, dp(2));
        content.addView(card, layout);
        return card;
    }

    private void showCarbohydrateTotals(JSONObject preview) {
        int carbs = preview.optInt("mealCarbs", -1);
        double netCarbs = preview.optDouble("netCarbsG");
        if (carbs < 0 && Double.isFinite(netCarbs) && netCarbs >= 0) {
            carbs = (int) Math.ceil(netCarbs);
        }
        int extended = preview.optInt("mealExtendedCarbs", -1);

        var totals = new LinearLayout(this);
        totals.setBackground(rounded(SURFACE, 8));
        totals.setPadding(0, dp(5), 0, dp(5));
        var totalsLayout = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        totalsLayout.topMargin = dp(6);
        content.addView(totals, totalsLayout);
        carbohydrateTotal(totals, R.string.carbs_label, carbs, 0xff98cbef);
        carbohydrateTotal(totals, R.string.active_meal_ecarbs, extended, 0xffffcf88);

        long sum = (long) carbs + extended;
        if (carbs < 0 || extended < 0 || sum <= 0) return;
        int share = Math.round(100f * carbs / sum);
        var bar = new LinearLayout(this);
        bar.setBackground(rounded(SURFACE, 5));
        bar.setClipToOutline(true);
        var barLayout = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(12));
        barLayout.setMargins(dp(9), dp(4), dp(9), 0);
        content.addView(bar, barLayout);
        carbohydrateShare(bar, carbs, share, R.string.carbs_label, 0xff98cbef);
        carbohydrateShare(bar, extended, 100 - share, R.string.active_meal_ecarbs, 0xffffcf88);
    }

    private void carbohydrateTotal(LinearLayout row, int labelId, int grams, int tint) {
        var column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        row.addView(column, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        var value = childBandLabel(column,
            grams >= 0 ? string(R.string.active_meal_grams, grams) : "—", ON_SURFACE, 17);
        value.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        childBandLabel(column, string(labelId), tint, 10);
    }

    private void carbohydrateShare(LinearLayout bar, int grams, int percentage, int labelId,
                                   int tint) {
        if (grams == 0) return;
        String display = java.text.NumberFormat.getPercentInstance(
            (localizedContext == null ? this : localizedContext)
                .getResources().getConfiguration().getLocales().get(0))
            .format(percentage / 100.0);
        var segment = childBandLabel(bar, percentage >= 18 ? display : "", BACKGROUND, 8);
        segment.setBackgroundColor(tint);
        segment.setContentDescription(string(labelId) + " " + display);
        segment.setLayoutParams(new LinearLayout.LayoutParams(0, dp(12), grams));
    }

    private void metric(LinearLayout row, String label, String value) {
        metric(row, label, value, false);
    }

    private void metric(LinearLayout row, String label, String value, boolean confirmed) {
        LinearLayout column = new LinearLayout(this);
        column.setOrientation(LinearLayout.VERTICAL);
        row.addView(column, new LinearLayout.LayoutParams(
            0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
        childBandLabel(column, confirmed ? "✓ " + label : label,
            confirmed ? ACCENT : MUTED, ActiveMealPresentation.AMOUNTS_LABEL_SIZE);
        childBandLabel(column, value, confirmed ? ACCENT : ON_SURFACE, ActiveMealPresentation.AMOUNTS_VALUE_SIZE)
            .setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    }

    private EditText field() {
        EditText field = new EditText(this);
        field.setTextSize(displayScale.dp(15));
        field.setTextColor(ON_SURFACE);
        field.setHintTextColor(MUTED);
        field.setBackgroundTintList(ColorStateList.valueOf(ACCENT));
        field.setMinHeight(dp(44));
        return field;
    }

    private void insetCompactButton(String label, boolean primary, View.OnClickListener action) {
        Button button = compactButton(content, label, primary, action);
        var layout = (LinearLayout.LayoutParams) button.getLayoutParams();
        int side = getResources().getDisplayMetrics().widthPixels * 6 / 100;
        layout.setMarginStart(side);
        layout.setMarginEnd(side);
        button.setLayoutParams(layout);
    }

    private Button compactButton(LinearLayout parent, String label, boolean primary,
                               View.OnClickListener action) {
        Button button = addButton(parent, label, primary, action);
        button.setTextSize(displayScale.dp(12));
        button.setMinHeight(dp(40));
        button.setMinimumHeight(dp(40));
        return button;
    }

    private Button addButton(LinearLayout parent, String label, boolean primary,
                           View.OnClickListener action) {
        Button button = new Button(this);
        button.setAllCaps(false);
        button.setText(label);
        button.setTextSize(displayScale.dp(14));
        button.setTextColor(primary ? BACKGROUND : ON_SURFACE);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setMinHeight(dp(48));
        button.setMinimumHeight(dp(48));
        button.setPadding(dp(9), dp(4), dp(9), dp(4));
        button.setBackground(new RippleDrawable(
            ColorStateList.valueOf(primary ? 0x22000000 : 0x33ffffff),
            rounded(primary ? ACCENT : SURFACE, 24), null));
        button.setOnClickListener(action);
        LinearLayout.LayoutParams layout = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        layout.setMargins(0, dp(4), 0, dp(2));
        parent.addView(button, layout);
        return button;
    }

    private void title(String label) {
        addLabel(content, label, ON_SURFACE, 18, true);
    }

    private void text(String label) {
        text(content, label);
    }

    private void text(LinearLayout section, String label) {
        addLabel(section, label, MUTED, 13, false);
    }

    private void addLabel(LinearLayout parent, String label, int color, int size, boolean bold) {
        label(parent, label, color, size, bold, Gravity.CENTER);
    }

    private void startLabel(LinearLayout parent, String label, int color, int size, boolean bold) {
        label(parent, label, color, size, bold, Gravity.START);
    }

    private TextView label(LinearLayout parent, String label, int color, int size, boolean bold, int gravity) {
        TextView view = new TextView(this);
        view.setGravity(gravity);
        view.setText(label);
        view.setTextColor(color);
        view.setTextSize(displayScale.dp(size));
        if (bold) view.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        view.setPadding(0, dp(2), 0, dp(2));
        parent.addView(view);
        return view;
    }
}
