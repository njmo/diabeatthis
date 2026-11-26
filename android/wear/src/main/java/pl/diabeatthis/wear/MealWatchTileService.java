package pl.diabeatthis.wear;

import static pl.diabeatthis.wear.WatchPalette.ACCENT;
import static pl.diabeatthis.wear.WatchPalette.BACKGROUND;
import static pl.diabeatthis.wear.WatchPalette.MUTED;
import static pl.diabeatthis.wear.WatchPalette.ON_SURFACE;
import static pl.diabeatthis.wear.WatchPalette.OUTLINE;
import static pl.diabeatthis.wear.WatchPalette.SURFACE;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import androidx.concurrent.futures.CallbackToFutureAdapter;
import androidx.wear.protolayout.ActionBuilders;
import androidx.wear.protolayout.ColorBuilders;
import androidx.wear.protolayout.DimensionBuilders;
import androidx.wear.protolayout.LayoutElementBuilders;
import androidx.wear.protolayout.ModifiersBuilders;
import androidx.wear.protolayout.ResourceBuilders;
import androidx.wear.protolayout.TimelineBuilders;
import androidx.wear.protolayout.TypeBuilders;
import androidx.wear.protolayout.expression.DynamicBuilders.DynamicInstant;
import androidx.wear.protolayout.expression.DynamicBuilders.DynamicInt32.IntFormatter;
import androidx.wear.protolayout.expression.DynamicBuilders.DynamicString;
import androidx.wear.tiles.RequestBuilders;
import androidx.wear.tiles.TileBuilders;
import androidx.wear.tiles.TileService;
import com.google.android.gms.wearable.CapabilityClient;
import com.google.android.gms.wearable.Wearable;
import com.google.common.util.concurrent.ListenableFuture;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.time.Instant;
import java.util.Date;
import java.util.Locale;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public final class MealWatchTileService extends TileService {
    private WatchDisplayScale displayScale;

    @Override
    public void onCreate() {
        super.onCreate();
        displayScale = new WatchDisplayScale(this);
    }

    private static final String CAPABILITY = "diabeatthis_meal_decision_phone";
    private static final String PATH = "/diabeatthis/meal-decision";
    private static final String RESOURCES_VERSION = "4";
    private static final String LOGO_RESOURCE = "diabeatthis_logo";
    private static final String GRADIENT_RESOURCE = "meal_gradient";
    private static final long INVITATION_GRACE_MS = 12000;
    private record AnnouncedInvitation(String id, long seenAt) {}
    private static volatile AnnouncedInvitation announcedInvitation;

    static void announceInvitation(Context context, String id) {
        AnnouncedInvitation current = announcedInvitation;
        if (current != null && current.id().equals(id) && announcedInvitationId() != null) return;
        announcedInvitation = new AnnouncedInvitation(id, SystemClock.elapsedRealtime());
        getUpdater(context).requestUpdate(MealWatchTileService.class);
    }

    static String announcedInvitationId() {
        AnnouncedInvitation current = announcedInvitation;
        return current != null && SystemClock.elapsedRealtime() - current.seenAt() < INVITATION_GRACE_MS
            ? current.id() : null;
    }

    static void removeInvitation(Context context, String id) {
        AnnouncedInvitation current = announcedInvitation;
        if (current != null && current.id().equals(id)) announcedInvitation = null;
        cachedOverview = null;
        getUpdater(context).requestUpdate(MealWatchTileService.class);
    }
    private static final byte[] LIST = "{\"version\":1,\"action\":\"list\"}"
        .getBytes(StandardCharsets.UTF_8);
    private record CachedOverview(JSONObject data, long receivedAt) {}
    private static volatile CachedOverview cachedOverview;

    static void cacheOverview(JSONObject overview) {
        cachedOverview = new CachedOverview(overview, SystemClock.elapsedRealtime());
    }

    private JSONObject recentOverview() {
        CachedOverview cached = cachedOverview;
        return cached != null && SystemClock.elapsedRealtime() - cached.receivedAt() < 15000
            ? cached.data() : null;
    }

    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    protected ListenableFuture<TileBuilders.Tile> onTileRequest(RequestBuilders.TileRequest request) {
        return CallbackToFutureAdapter.getFuture(completer -> {
            String incomingId = announcedInvitationId();
            CachedOverview beforeFetch = cachedOverview;
            JSONObject cached = recentOverview();
            boolean previewingAnnouncement = incomingId != null && matchingRequest(cached, incomingId) == null;
            if (previewingAnnouncement) completer.set(tile(cached));
            Runnable timeout = () -> completer.set(tile(recentOverview()));
            handler.postDelayed(timeout, 2200);
            completer.addCancellationListener(() -> handler.removeCallbacks(timeout), Runnable::run);
            Wearable.getCapabilityClient(this).getCapability(CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .addOnSuccessListener(capability -> {
                    if (capability.getNodes().size() != 1) {
                        handler.removeCallbacks(timeout);
                        completer.set(tile(recentOverview()));
                        return;
                    }
                    String node = capability.getNodes().iterator().next().getId();
                    Wearable.getMessageClient(this).sendRequest(node, PATH, LIST)
                        .addOnCompleteListener(task -> {
                            handler.removeCallbacks(timeout);
                            JSONObject live = task.isSuccessful() ? parse(task.getResult()) : null;
                            if (cachedOverview != beforeFetch && recentOverview() != null) {
                                // The activity or another tile fetch has already received a newer overview.
                                live = recentOverview();
                            } else if (live != null) {
                                cacheOverview(live);
                            }
                            if (previewingAnnouncement) {
                                if (matchingRequest(live, incomingId) != null) {
                                    AnnouncedInvitation current = announcedInvitation;
                                    if (current != null && current.id().equals(incomingId)) {
                                        announcedInvitation = null;
                                    }
                                    getUpdater(this).requestUpdate(MealWatchTileService.class);
                                }
                            } else {
                                boolean rendered = completer.set(tile(live == null ? recentOverview() : live));
                                if (!rendered && live != null &&
                                        (cached == null || !live.toString().equals(cached.toString()))) {
                                    getUpdater(this).requestUpdate(MealWatchTileService.class);
                                }
                            }
                        });
                })
                .addOnFailureListener(error -> {
                    handler.removeCallbacks(timeout);
                    completer.set(tile(recentOverview()));
                });
            return "Read meal status";
        });
    }

    @Override
    protected ListenableFuture<ResourceBuilders.Resources> onTileResourcesRequest(
            RequestBuilders.ResourcesRequest request) {
        return CallbackToFutureAdapter.getFuture(completer -> {
            var gradient = WatchPalette.gradient(142);
            var bitmap = Bitmap.createBitmap(192, 192, Bitmap.Config.ARGB_8888);
            gradient.setBounds(0, 0, bitmap.getWidth(), bitmap.getHeight());
            gradient.draw(new Canvas(bitmap));
            var pixels = ByteBuffer.allocate(bitmap.getByteCount());
            bitmap.copyPixelsToBuffer(pixels);
            var image = new ResourceBuilders.ImageResource.Builder()
                .setInlineResource(new ResourceBuilders.InlineImageResource.Builder()
                    .setFormat(ResourceBuilders.IMAGE_FORMAT_ARGB_8888)
                    .setWidthPx(bitmap.getWidth())
                    .setHeightPx(bitmap.getHeight())
                    .setData(pixels.array()).build())
                .build();
            completer.set(new ResourceBuilders.Resources.Builder()
                .setVersion(RESOURCES_VERSION)
                .addIdToImageMapping(GRADIENT_RESOURCE, image)
                .addIdToImageMapping(LOGO_RESOURCE, new ResourceBuilders.ImageResource.Builder()
                    .setAndroidResourceByResId(new ResourceBuilders.AndroidImageResourceByResId.Builder()
                        .setResourceId(R.mipmap.ic_launcher).build())
                    .build())
                .build());
            return "Meal tile resources";
        });
    }

    private JSONObject parse(byte[] bytes) {
        if (bytes == null) return null;
        try {
            JSONObject result = new JSONObject(new String(bytes, StandardCharsets.UTF_8));
            return result.optInt("version") == 1 && "ok".equals(result.optString("status"))
                ? result : null;
        } catch (JSONException ignored) {
            return null;
        }
    }

    private TileBuilders.Tile tile(JSONObject overview) {
        Context labels = overview == null ? WatchLanguage.savedLabels(this)
            : WatchLanguage.update(this, overview.optString("languageTag"));
        String heading = labels.getString(R.string.child_plans);
        String name = null;
        String state = null;
        JSONObject invitation = null;
        long summaryMealId = 0;
        long startMealId = 0;
        boolean treatmentSurplus = false;
        ActiveMealPresentation activeMeal = null;
        JSONObject progress = null;
        JSONArray plans = overview == null ? null : overview.optJSONArray("plans");
        if (overview != null) {
            JSONObject active = activeMeal(plans);
            if (active == null && "child".equals(overview.optString("mode"))) active = readyMeal(plans);
            if (active != null) {
                treatmentSurplus = active.optBoolean("treatmentSurplus");
                activeMeal = ActiveMealPresentation.from(labels, active, "child".equals(overview.optString("mode")));
                heading = labels.getString(activeMeal.heading());
                if ("child".equals(overview.optString("mode")) &&
                        (activeMeal.readyToStart() || activeMeal.canStartEating())) startMealId = active.optLong("mealId");
                name = activeMeal.title();
                state = activeMeal.status();
                progress = activeMeal.progress();
                if ("child".equals(overview.optString("mode")) &&
                        activeMeal.canFinishEating()) {
                    summaryMealId = active.optLong("mealId");
                }
            }
        }
        boolean child = overview != null && "child".equals(overview.optString("mode"));
        boolean linkedPlans = false;
        boolean active = state != null;
        String invitationId = null;
        if (!active && !child) {
            invitationId = announcedInvitationId();
            invitation = invitationId == null && overview != null
                ? availableRequest(overview.optJSONArray("requests")) : matchingRequest(overview, invitationId);
            if (invitation != null) {
                invitationId = invitation.optString("requestId");
                name = invitation.optString("mealName");
            }
            if (invitationId != null) heading = labels.getString(R.string.meal_tile_invitation);
        }
        JSONObject childRequest = child && !active
            ? pendingChildRequest(overview.optJSONArray("requests"), System.currentTimeMillis()) : null;
        boolean waitingForDecision = childRequest != null;
        boolean planned = !active && invitationId == null && !waitingForDecision;
        boolean showBolusAmounts = activeMeal != null && activeMeal.showsBolusAmounts();
        var body = centeredColumn();
        if (planned || active) {
            body.addContent(gap(activeMeal == null ? 10 : activeMeal.topPadding()))
                .addContent(new LayoutElementBuilders.Image.Builder()
                    .setResourceId(LOGO_RESOURCE)
                    .setWidth(DimensionBuilders.dp(displayScale.dp(activeMeal == null ? 20 : activeMeal.logoSize())))
                    .setHeight(DimensionBuilders.dp(displayScale.dp(activeMeal == null ? 20 : activeMeal.logoSize())))
                    .build())
                .addContent(gap(1))
                .addContent(text(getApplicationInfo().loadLabel(getPackageManager()).toString(),
                    8, MUTED, 1))
                .addContent(gap(activeMeal == null ? 6 : activeMeal.headingGap()));
        }
        if (waitingForDecision) {
            if ("answered".equals(childRequest.optString("status"))) {
                body.addContent(text(childRequest.optString("mealName"), 12, ACCENT, 2))
                    .addContent(gap(5))
                    .addContent(text(labels.getString(R.string.answered), 16, ON_SURFACE, 2))
                    .addContent(gap(6))
                    .addContent(text(labels.getString(R.string.open_request), 12, ACCENT, 1));
            } else {
                addChildWaiting(body, labels, childRequest);
            }
        } else {
            body.addContent(text(heading, active ? 11 : planned ? 12 : 13, active ? ACCENT : MUTED, 2));
        }
        if (invitationId != null || (name != null && !name.isBlank())) {
            var meal = active ? centeredColumn() : mealContents();
            if (name != null && !name.isBlank()) {
                meal.addContent(text(name, active ? ActiveMealPresentation.TITLE_SIZE : 19, ON_SURFACE, active ? 2 : 3));
            }
            if (active && treatmentSurplus) {
                meal.addContent(text(labels.getString(R.string.active_meal_treatment_surplus), 11,
                    ActiveMealPresentation.WARNING_COLOR, 2));
            }
            if (activeMeal != null && activeMeal.waitUntil() > 0) {
                meal.addContent(waitClock(activeMeal.waitUntil(), ActiveMealPresentation.WAIT_CLOCK_FRACTION));
            }
            if (invitationId != null) {
                boolean claimed = invitation != null
                    && invitation.optLong("claimUntilMs") > System.currentTimeMillis();
                meal.addContent(text(labels.getString(claimed ? R.string.open_request
                    : R.string.claim_request), 15, ACCENT, 1));
            }
            if (showBolusAmounts) {
                if (!activeMeal.waitsForExtendedCarbs()) {
                    meal.addContent(gap(2))
                        .addContent(text(labels.getString(R.string.active_meal_aaps), ActiveMealPresentation.AMOUNTS_TITLE_SIZE, MUTED, 1));
                }
                meal.addContent(gap(2)).addContent(bolusAmounts(labels, progress));
            }
            if (state != null && !state.isEmpty()) meal.addContent(text(state, ActiveMealPresentation.STATUS_SIZE, MUTED, 2));
            ModifiersBuilders.Clickable click = invitationId == null ? null : openWatch(
                "openInvitation", MealDecisionWatchActivity.EXTRA_TILE_REQUEST_ID, invitationId);
            body.addContent(gap(active ? 2 : 6));
            body.addContent(active ? meal.build() : mealBand(meal, click));
        } else if (planned && plans != null) {
            int shown = 0;
            Locale locale = labels.getResources().getConfiguration().getLocales().get(0);
            var time = new SimpleDateFormat("HH:mm", locale);
            for (int i = 0; i < plans.length() && shown < 2; i++) {
                JSONObject plan = plans.optJSONObject(i);
                if (plan == null || plan.optString("mealName").isBlank()) continue;
                long at = plan.optLong("plannedAtMs");
                var meal = mealContents();
                if (at > 0) {
                    meal.addContent(text(time.format(new Date(at)), 11, ACCENT, 1));
                }
                meal.addContent(text(plan.optString("mealName"), 12, ON_SURFACE, 3));
                long mealId = plan.optLong("mealId");
                ModifiersBuilders.Clickable click = null;
                if (child && mealId > 0) {
                    click = openMeal("planned-" + mealId,
                        MealDecisionWatchActivity.EXTRA_PLANNED_MEAL_ID, mealId);
                    linkedPlans = true;
                    if (!plan.optString("acceptedDecision").isEmpty()) {
                        long due = plan.optLong("bolusDueAtMs");
                        if (due > 0) {
                            meal.addContent(text(labels.getString(R.string.scheduled_bolus_at,
                                time.format(new Date(due))), 12, ACCENT, 2));
                        }
                    }
                }
                body.addContent(gap(5)).addContent(mealBand(meal, click));
                shown++;
            }
            if (shown == 0) {
                body.addContent(gap(6))
                    .addContent(text(labels.getString(R.string.meal_tile_empty), 14, ON_SURFACE, 2));
            }
        }
        var background = new ModifiersBuilders.Modifiers.Builder()
            .setBackground(new ModifiersBuilders.Background.Builder()
                .setColor(ColorBuilders.argb(BACKGROUND)).build());
        if (waitingForDecision) {
            background.setClickable(openWatch("openChildWaiting",
                MealDecisionWatchActivity.EXTRA_TILE_REQUEST_ID, childRequest.optString("requestId")));
        } else if (child && !linkedPlans && name == null) {
            background.setClickable(openMeal("openMeals",
                MealDecisionWatchActivity.EXTRA_SUMMARY_MEAL_ID, summaryMealId));
        }
        var layout = new LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(planned ? LayoutElementBuilders.VERTICAL_ALIGN_TOP
                : LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .setModifiers(background.build())
            .addContent(new LayoutElementBuilders.Image.Builder()
                .setResourceId(GRADIENT_RESOURCE)
                .setWidth(DimensionBuilders.dp(displayScale.dp(192)))
                .setHeight(DimensionBuilders.dp(displayScale.dp(192)))
                .setContentScaleMode(LayoutElementBuilders.CONTENT_SCALE_MODE_FILL_BOUNDS)
                .build())
            .addContent(active ? new LayoutElementBuilders.Box.Builder()
                .setWidth(DimensionBuilders.expand())
                .setHeight(DimensionBuilders.expand())
                .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_TOP)
                .addContent(body.build()).build() : body.build());
        if (progress != null && progress.optInt("count") > 0) {
            layout.addContent(progressArc(progress));
        }
        if (summaryMealId > 0 || startMealId > 0) {
            layout.addContent(new LayoutElementBuilders.Box.Builder()
                .setWidth(DimensionBuilders.expand())
                .setHeight(DimensionBuilders.expand())
                .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_BOTTOM)
                .addContent(centeredColumn()
                    .addContent(startMealId > 0
                        ? mealActionButton(labels.getString(R.string.start_eating),
                            openMeal("planned-" + startMealId,
                                MealDecisionWatchActivity.EXTRA_PLANNED_MEAL_ID, startMealId))
                        : mealEatenButton(labels, summaryMealId))
                    .addContent(gap(ActiveMealPresentation.ARC_HEIGHT
                        + ActiveMealPresentation.ARC_BOTTOM_PADDING))
                    .build())
                .build());
        }
        return new TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setFreshnessIntervalMillis(waitingForDecision || announcedInvitationId() != null
                || showBolusAmounts ? 3000 : 30000)
            .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(layout.build()))
            .build();
    }

    private LayoutElementBuilders.Column.Builder centeredColumn() {
        return new LayoutElementBuilders.Column.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER);
    }

    private LayoutElementBuilders.Row bolusAmounts(Context labels, JSONObject progress) {
        var row = new LayoutElementBuilders.Row.Builder()
            .setModifiers(new ModifiersBuilders.Modifiers.Builder().setBackground(
                new ModifiersBuilders.Background.Builder()
                    .setColor(ColorBuilders.argb(SURFACE))
                    .setCorner(new ModifiersBuilders.Corner.Builder()
                        .setRadius(DimensionBuilders.dp(displayScale.dp(7))).build())
                    .build()).build());
        row.addContent(bolusAmount(labels, R.string.carbs_label, progress.optInt("carbs"),
            progress.optBoolean("carbsEntered")));
        if (progress.has("extendedCarbs")) {
            row.addContent(bolusAmount(labels, R.string.active_meal_ecarbs,
                progress.optInt("extendedCarbs"), progress.optBoolean("extendedCarbsConfirmed")));
        }
        return row.build();
    }

    private LayoutElementBuilders.Column bolusAmount(Context labels, int label, int grams, boolean confirmed) {
        return centeredColumn()
            .setWidth(DimensionBuilders.dp(displayScale.dp(67)))
            .addContent(gap(2))
            .addContent(text((confirmed ? "✓ " : "") + labels.getString(label),
                ActiveMealPresentation.AMOUNTS_LABEL_SIZE, confirmed ? ACCENT : MUTED, 1))
            .addContent(text(labels.getString(R.string.active_meal_grams, grams),
                ActiveMealPresentation.AMOUNTS_VALUE_SIZE, confirmed ? ACCENT : ON_SURFACE, 1))
            .addContent(gap(2))
            .build();
    }

    private LayoutElementBuilders.Box progressArc(JSONObject progress) {
        int count = progress.optInt("count");
        var arc = new LayoutElementBuilders.Arc.Builder()
            .setAnchorAngle(DimensionBuilders.degrees(180))
            .setAnchorType(LayoutElementBuilders.ARC_ANCHOR_CENTER);
        for (int i = count - 1; i >= 0; i--) {
            if (i < count - 1) arc.addContent(new LayoutElementBuilders.ArcSpacer.Builder()
                .setLength(DimensionBuilders.degrees(4)).build());
            int color = ActiveMealPresentation.progressColor(progress, i);
            arc.addContent(new LayoutElementBuilders.ArcLine.Builder()
                .setLength(DimensionBuilders.degrees(88f / count - 4))
                .setThickness(DimensionBuilders.dp(displayScale.dp(3)))
                .setColor(ColorBuilders.argb(color))
                .build());
        }
        return new LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.dp(displayScale.dp(169)))
            .setHeight(DimensionBuilders.dp(displayScale.dp(169)))
            .addContent(arc.build())
            .build();
    }

    private LayoutElementBuilders.Box mealEatenButton(Context labels, long mealId) {
        return mealActionButton(labels.getString(R.string.meal_eaten),
            openMeal("mealEaten", MealDecisionWatchActivity.EXTRA_SUMMARY_MEAL_ID, mealId));
    }

    private LayoutElementBuilders.Box mealActionButton(String label,
                                                       ModifiersBuilders.Clickable click) {
        return new LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.dp(displayScale.dp(ActiveMealPresentation.EATEN_BUTTON_WIDTH)))
            .setHeight(DimensionBuilders.dp(displayScale.dp(ActiveMealPresentation.EATEN_BUTTON_HEIGHT)))
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .setModifiers(new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder()
                    .setColor(ColorBuilders.argb(ACCENT))
                    .setCorner(new ModifiersBuilders.Corner.Builder()
                        .setRadius(DimensionBuilders.dp(displayScale.dp(15))).build())
                    .build())
                .setClickable(click)
                .build())
            .addContent(text(label, 13, BACKGROUND, 1))
            .build();
    }

    private LayoutElementBuilders.Column.Builder mealContents() {
        return new LayoutElementBuilders.Column.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setModifiers(new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder()
                    .setColor(ColorBuilders.argb(SURFACE)).build())
                .setPadding(new ModifiersBuilders.Padding.Builder()
                    .setStart(DimensionBuilders.dp(displayScale.dp(12))).setEnd(DimensionBuilders.dp(displayScale.dp(12)))
                    .setTop(DimensionBuilders.dp(displayScale.dp(5))).setBottom(DimensionBuilders.dp(displayScale.dp(5)))
                    .build())
                .build());
    }

    private ModifiersBuilders.Clickable openMeal(String id, String extra, long mealId) {
        return openWatch(id, extra, mealId > 0 ? Long.toString(mealId) : "");
    }

    private ModifiersBuilders.Clickable openWatch(String id, String extra, String value) {
        var destination = new ActionBuilders.AndroidActivity.Builder()
            .setPackageName(getPackageName())
            .setClassName(MealDecisionWatchActivity.class.getName());
        if (!value.isEmpty()) {
            destination.addKeyToExtraMapping(extra, new ActionBuilders.AndroidStringExtra.Builder()
                .setValue(value).build());
        }
        return new ModifiersBuilders.Clickable.Builder().setId(id)
            .setOnClick(new ActionBuilders.LaunchAction.Builder()
                .setAndroidActivity(destination.build()).build())
            .build();
    }

    private LayoutElementBuilders.Column mealBand(LayoutElementBuilders.Column.Builder meal,
            ModifiersBuilders.Clickable click) {
        var band = new LayoutElementBuilders.Column.Builder()
            .setWidth(DimensionBuilders.expand())
            .addContent(horizontalRule())
            .addContent(meal.build())
            .addContent(horizontalRule());
        if (click != null) {
            band.setModifiers(new ModifiersBuilders.Modifiers.Builder().setClickable(click).build());
        }
        return band.build();
    }

    private LayoutElementBuilders.Spacer gap(int height) {
        return new LayoutElementBuilders.Spacer.Builder().setHeight(DimensionBuilders.dp(displayScale.dp(height))).build();
    }

    private LayoutElementBuilders.Box horizontalRule() {
        return new LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.dp(displayScale.dp(1)))
            .setModifiers(new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder()
                    .setColor(ColorBuilders.argb(OUTLINE)).build())
                .build())
            .build();
    }

    private void addChildWaiting(LayoutElementBuilders.Column.Builder body, Context labels,
                                 JSONObject request) {
        var waiting = ChildWaitingPresentation.from(request, System.currentTimeMillis());
        body.addContent(new LayoutElementBuilders.Box.Builder()
                .setWidth(DimensionBuilders.dp(displayScale.dpAtFraction(.74f)))
                .addContent(text(ActiveMealPresentation.splitTitle(request.optString("mealName")),
                    10, ACCENT, 3))
                .build())
            .addContent(gap(3))
            .addContent(text(labels.getString(waiting.heading()), 14, ON_SURFACE, 2));
        if (!waiting.caregiver().isEmpty()) {
            body.addContent(text(waiting.caregiver(), 11, MUTED, 1));
        }
        body.addContent(gap(4))
            .addContent(waitClock(waiting.deadline()))
            .addContent(text(labels.getString(R.string.child_decision_timer), 11, MUTED, 2))
            .addContent(gap(5))
            .addContent(new LayoutElementBuilders.Row.Builder()
                .addContent(waitingSegment(waiting.claimed()))
                .addContent(new LayoutElementBuilders.Spacer.Builder()
                    .setWidth(DimensionBuilders.dp(displayScale.dp(4))).build())
                .addContent(waitingSegment(waiting.deciding())).build());
    }

    private LayoutElementBuilders.Box waitingSegment(boolean marked) {
        return new LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.dp(displayScale.dp(42)))
            .setHeight(DimensionBuilders.dp(displayScale.dp(3)))
            .setModifiers(new ModifiersBuilders.Modifiers.Builder()
                .setBackground(new ModifiersBuilders.Background.Builder()
                    .setColor(ColorBuilders.argb(marked ? ACCENT : SURFACE)).build())
                .build()).build();
    }

    static JSONObject pendingChildRequest(JSONArray requests, long now) {
        if (requests == null) return null;
        JSONObject waiting = null;
        for (int i = 0; i < requests.length(); i++) {
            JSONObject request = requests.optJSONObject(i);
            if (request == null || request.optString("requestId").isEmpty()) continue;
            String status = request.optString("status");
            if (request.optLong("deadlineMs") <= now) continue;
            if ("answered".equals(status) && request.optJSONObject("decision") != null) return request;
            if (waiting == null && ("waiting".equals(status) || "accepting".equals(status))) {
                waiting = request;
            }
        }
        return waiting;
    }

    static JSONObject readyMeal(JSONArray plans) {
        if (plans == null) return null;
        for (int i = 0; i < plans.length(); i++) {
            JSONObject meal = plans.optJSONObject(i);
            if (meal != null && ActiveMealPresentation.isReadyToStart(meal)) return meal;
        }
        return null;
    }

    static JSONObject activeMeal(JSONArray plans) {
        if (plans == null) return null;
        for (int i = 0; i < plans.length(); i++) {
            JSONObject meal = plans.optJSONObject(i);
            if (meal != null && !meal.optString("activeStatus").isEmpty()) return meal;
        }
        return null;
    }

    private static JSONObject matchingRequest(JSONObject overview, String id) {
        if (overview == null || id == null || !"caregiver".equals(overview.optString("mode"))) return null;
        JSONArray requests = overview.optJSONArray("requests");
        if (requests == null) return null;
        for (int i = 0; i < requests.length(); i++) {
            JSONObject row = requests.optJSONObject(i);
            if (row != null && id.equals(row.optString("requestId"))
                    && row.optLong("deadlineMs") > System.currentTimeMillis()) return row;
        }
        return null;
    }

    private static JSONObject availableRequest(JSONArray requests) {
        if (requests == null) return null;
        for (int i = 0; i < requests.length(); i++) {
            JSONObject row = requests.optJSONObject(i);
            if (row != null && row.optLong("deadlineMs") > System.currentTimeMillis()) return row;
        }
        return null;
    }

    private LayoutElementBuilders.Text text(String value, int size, int color, int maxLines) {
        return new LayoutElementBuilders.Text.Builder()
            .setText(value)
            .setMultilineAlignment(LayoutElementBuilders.TEXT_ALIGN_CENTER)
            .setMaxLines(maxLines)
            .setOverflow(LayoutElementBuilders.TEXT_OVERFLOW_ELLIPSIZE_END)
            .setFontStyle(new LayoutElementBuilders.FontStyle.Builder()
                .setSize(DimensionBuilders.sp(displayScale.dp(size))).setColor(ColorBuilders.argb(color)).build())
            .build();
    }

    private LayoutElementBuilders.Text waitClock(long deadline) {
        return waitClock(deadline, 22f / 192f);
    }

    private LayoutElementBuilders.Text waitClock(long deadline, float fraction) {
        var duration = DynamicInstant.platformTimeWithSecondsPrecision().durationUntil(
            DynamicInstant.withSecondsPrecision(Instant.ofEpochMilli(deadline)));
        var twoDigits = new IntFormatter.Builder()
            .setMinIntegerDigits(2)
            .setGroupingUsed(false)
            .build();
        var clock = DynamicString.onCondition(duration.toIntSeconds().gt(0))
            .use(duration.toIntMinutes().format(twoDigits)
                .concat(DynamicString.constant(":"))
                .concat(duration.getSecondsPart().format(twoDigits)))
            .elseUse("00:00");
        return new LayoutElementBuilders.Text.Builder()
            .setText(new TypeBuilders.StringProp.Builder("—").setDynamicValue(clock).build())
            .setLayoutConstraintsForDynamicText(new TypeBuilders.StringLayoutConstraint.Builder("000:00").build())
            .setMultilineAlignment(LayoutElementBuilders.TEXT_ALIGN_CENTER)
            .setMaxLines(1)
            .setFontStyle(new LayoutElementBuilders.FontStyle.Builder()
                .setSize(DimensionBuilders.sp(displayScale.dpAtFraction(fraction))).setColor(ColorBuilders.argb(ON_SURFACE)).build())
            .build();
    }
}
