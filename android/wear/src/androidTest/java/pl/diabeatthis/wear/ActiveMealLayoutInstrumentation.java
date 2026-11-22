package pl.diabeatthis.wear;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.Handler;
import android.util.DisplayMetrics;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.Chronometer;
import android.widget.TextView;
import androidx.wear.protolayout.LayoutElementBuilders;
import androidx.wear.tiles.TileBuilders;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.json.JSONArray;
import org.json.JSONObject;

/** Compares actual native controls with the tile layout for identical fixtures. */
public final class ActiveMealLayoutInstrumentation extends Instrumentation {
    private record VisualText(String text, int sizePx, int color) {}

    @Override
    public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }

    @Override
    public void onStart() {
        Bundle result = new Bundle();
        MealDecisionWatchActivity activity = null;
        try {
            Context target = getTargetContext();
            var intent = new Intent(target, MealDecisionWatchActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity = (MealDecisionWatchActivity) startActivitySync(intent);
            var running = activity;
            var failure = new AtomicReference<Throwable>();
            for (String stage : List.of("waiting", "waiting-ecarbs", "caregiver-waiting", "eating", "extra", "bolus")) {
                runOnMainSync(() -> {
                    try {
                        verify(running, stage);
                    } catch (Throwable error) {
                        failure.set(error);
                    }
                });
                if (failure.get() != null) throw new AssertionError(stage, failure.get());
            }
            runOnMainSync(() -> {
                try {
                    verifyAcceptedPlan(running);
                    verifyWaitingTile(running);
                    verifyAdvisorPage(running);
                } catch (Throwable error) {
                    failure.set(error);
                }
            });
            if (failure.get() != null) throw new AssertionError("Accepted plan", failure.get());
            result.putString("stream", "\n6 active meal layouts, 3 accepted plans, 5 decision tile states and the advisor page passed\n");
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "\n" + android.util.Log.getStackTraceString(error) + "\n");
            finish(Activity.RESULT_CANCELED, result);
        } finally {
            if (activity != null) {
                var running = activity;
                runOnMainSync(running::finish);
            }
        }
    }

    private void verify(MealDecisionWatchActivity activity, String stage) throws Exception {
        boolean eats = stage.equals("eating") || stage.equals("extra");
        boolean caregiver = stage.equals("caregiver-waiting");
        boolean pendingExtended = stage.equals("waiting-ecarbs");
        boolean waits = stage.equals("waiting") || caregiver || pendingExtended;
        JSONObject progress = new JSONObject()
            .put("stage", waits ? "waiting" : stage)
            .put("count", 3)
            .put("index", 1)
            .put("completed", new JSONArray().put(0));
        if (waits) progress.put("waitUntilMs", System.currentTimeMillis() + 60000);
        if (pendingExtended) progress.put("carbs", 18).put("extendedCarbs", 4)
            .put("carbsEntered", true).put("waitingForExtendedCarbs", true);
        if (stage.equals("bolus")) progress.put("carbs", 18).put("extendedCarbs", 4)
            .put("carbsEntered", true).put("extendedCarbsConfirmed", true);
        JSONObject meal = new JSONObject().put("mealId", 1)
            .put("mealName", "Podwieczorek: jabłko")
            .put("activeStatus", stage)
            .put("treatmentSurplus", caregiver || pendingExtended)
            .put("canComplete", eats)
            .put("progress", progress);

        var locale = field("localizedContext");
        Context labels = WatchLanguage.update(activity, "pl");
        locale.set(activity, labels);
        var generation = field("requestGeneration");
        int stamp = generation.getInt(activity) + 1;
        generation.setInt(activity, stamp);
        ((Handler) field("handler").get(activity)).removeCallbacksAndMessages(null);
        ((Handler) field("inboxHandler").get(activity)).removeCallbacksAndMessages(null);
        Method render = MealDecisionWatchActivity.class.getDeclaredMethod(
            "renderActiveMeal", String.class, JSONObject.class, boolean.class, int.class);
        render.setAccessible(true);
        render.invoke(activity, null, meal, !caregiver, stamp);

        var root = (View) field("root").get(activity);
        var nativeContent = new ArrayList<VisualText>();
        readApp(root, nativeContent);
        var tile = new MealWatchTileService();
        var attach = ContextWrapper.class.getDeclaredMethod("attachBaseContext", Context.class);
        attach.setAccessible(true);
        attach.invoke(tile, labels);
        tile.onCreate();
        Method tileLayout = MealWatchTileService.class.getDeclaredMethod("tile", JSONObject.class);
        tileLayout.setAccessible(true);
        var overview = new JSONObject().put("languageTag", "pl").put("mode", caregiver ? "caregiver" : "child")
            .put("plans", new JSONArray().put(meal));
        if (stage.equals("bolus")) {
            overview.put("requests", new JSONArray().put(new JSONObject()
                .put("requestId", "a".repeat(32))
                .put("mealId", 1)
                .put("mealName", "Podwieczorek: jabłko")
                .put("status", "waiting")
                .put("stage", "decision")
                .put("deadlineMs", System.currentTimeMillis() + 60000)
                .put("claimUntilMs", System.currentTimeMillis() + 60000)));
        }
        var built = (TileBuilders.Tile) tileLayout.invoke(tile, overview);
        var elements = new ArrayList<VisualText>();
        var layout = built.getTileTimeline().getTimelineEntries().get(0).getLayout().getRoot();
        readTile(layout, elements, labels.getResources().getDisplayMetrics());
        if (!nativeContent.equals(elements)) {
            throw new AssertionError("Watch activity: " + nativeContent + "; tile: " + elements);
        }
        var shown = elements.stream().map(VisualText::text).toList();
        if (shown.contains(labels.getString(R.string.active_meal_treatment_surplus)) != (caregiver || pendingExtended)) {
            throw new AssertionError("Unexpected treatment surplus warning");
        }
        if (pendingExtended && (!shown.contains(labels.getString(R.string.active_meal_waiting_ecarbs))
                || !shown.contains("4 g"))) throw new AssertionError("Missing pending eCarbs");
        if (caregiver && !shown.contains(labels.getString(R.string.active_meal_caregiver_waiting))) {
            throw new AssertionError("Missing caregiver delivery status");
        }
        if (waits && shown.contains(labels.getString(R.string.start_eating))
                != (!caregiver && !pendingExtended)) {
            throw new AssertionError("Start eating must only be available to the child");
        }
        if (eats && !shown.contains(labels.getString(R.string.meal_eaten))) {
            throw new AssertionError("Missing eating completion action");
        }
        if (!eats && shown.contains(labels.getString(R.string.meal_eaten))) {
            throw new AssertionError("Completion action is visible while waiting");
        }
        if (stage.equals("bolus") && (!shown.contains("18 g") || !shown.contains("4 g")
                || !shown.contains("✓ " + labels.getString(R.string.carbs_label))
                || !shown.contains("✓ " + labels.getString(R.string.active_meal_ecarbs)))) {
            throw new AssertionError("Both amounts must show confirmation");
        }
        if (stage.equals("extra")) {
            verifyExtraSummary(activity, labels, root, meal);
        }
    }

    private void verifyAcceptedPlan(MealDecisionWatchActivity activity) throws Exception {
        Context labels = WatchLanguage.update(activity, "pl");
        field("localizedContext").set(activity, labels);
        Method render = MealDecisionWatchActivity.class.getDeclaredMethod(
            "renderPlannedMeal", String.class, JSONObject.class);
        render.setAccessible(true);
        Method renderReady = MealDecisionWatchActivity.class.getDeclaredMethod(
            "renderActiveMeal", String.class, JSONObject.class, boolean.class, int.class);
        renderReady.setAccessible(true);
        Method tileLayout = MealWatchTileService.class.getDeclaredMethod("tile", JSONObject.class);
        tileLayout.setAccessible(true);
        var tile = new MealWatchTileService();
        var attach = ContextWrapper.class.getDeclaredMethod("attachBaseContext", Context.class);
        attach.setAccessible(true);
        attach.invoke(tile, labels);
        tile.onCreate();
        for (String decision : List.of("eatNowBolusLater", "bolusAndEatNow", "bolusWaitThenEat")) {
            JSONObject plan = new JSONObject().put("mealId", 1).put("mealName", "Jabłko")
                .put("acceptedDecision", decision);
            boolean scheduled = decision.equals("bolusWaitThenEat");
            if (scheduled) plan.put("bolusDueAtMs", System.currentTimeMillis() + 600000);
            if (scheduled) {
                render.invoke(activity, null, plan);
            } else {
                renderReady.invoke(activity, null, plan, true, -1);
                var ready = ActiveMealPresentation.from(labels, plan, true);
                if (ready.count() != 2 || ready.index() != -1 ||
                        ActiveMealPresentation.progressColor(ready.progress(), 0) == WatchPalette.ACCENT ||
                        ActiveMealPresentation.progressColor(ready.progress(), 1) == WatchPalette.ACCENT) {
                    throw new AssertionError("Expected two inactive segments before starting");
                }
            }
            var root = (View) field("root").get(activity);
            var overview = new JSONObject().put("languageTag", "pl").put("mode", "child")
                .put("plans", new JSONArray().put(plan));
            var built = (TileBuilders.Tile) tileLayout.invoke(tile, overview);
            var elements = new ArrayList<VisualText>();
            readTile(built.getTileTimeline().getTimelineEntries().get(0).getLayout().getRoot(),
                elements, labels.getResources().getDisplayMetrics());
            boolean appStart = button(root, "Zaczynam jeść") != null;
            boolean tileStart = elements.stream().anyMatch(text -> text.text().equals("Zaczynam jeść"));
            if (scheduled && (button(root, "Wstecz  ›") == null ||
                button(root, labels.getString(R.string.child_skip_meal)) == null ||
                field("swipeRight").get(activity) == null)) {
                throw new AssertionError("Missing skip control or rightward back gesture");
            }
            if (scheduled && elements.stream().noneMatch(text ->
                    text.text().startsWith("Krok bolusa o "))) {
                throw new AssertionError("Missing scheduled time on the tile");
            }
            if (!scheduled) {
                var app = new ArrayList<VisualText>();
                readApp(root, app);
                if (!app.equals(elements)) {
                    throw new AssertionError("Ready meal differs between app and tile: " + app + " / " + elements);
                }
            }
            if (appStart != !scheduled || tileStart != !scheduled) {
                throw new AssertionError("Wrong accepted-plan start action for " + decision);
            }
        }
    }

    private void verifyWaitingTile(MealDecisionWatchActivity activity) throws Exception {
        Context labels = WatchLanguage.update(activity, "pl");
        var tile = new MealWatchTileService();
        var attach = ContextWrapper.class.getDeclaredMethod("attachBaseContext", Context.class);
        attach.setAccessible(true);
        attach.invoke(tile, labels);
        tile.onCreate();
        Method render = MealWatchTileService.class.getDeclaredMethod("tile", JSONObject.class);
        render.setAccessible(true);
        long deadline = System.currentTimeMillis() + 60000;
        for (String stage : List.of("unclaimed", "context", "decision", "answered", "expired")) {
            boolean expired = stage.equals("expired");
            boolean answered = stage.equals("answered");
            boolean claimed = stage.equals("context") || stage.equals("decision");
            var request = new JSONObject().put("requestId", "a".repeat(32)).put("mealId", 1)
                .put("mealName", "Jabłko").put("status", "waiting")
                .put("deadlineMs", expired ? 1 : deadline);
            if (answered) request.put("status", "answered")
                .put("decision", new JSONObject().put("type", "eatThenInsulin"));
            if (claimed) request.put("caregiverName", "Anna").put("stage", stage)
                .put("claimUntilMs", deadline);
            var overview = new JSONObject().put("languageTag", "pl").put("mode", "child")
                .put("requests", new JSONArray().put(request))
                .put("plans", new JSONArray().put(new JSONObject()
                    .put("mealId", 1).put("mealName", "Jabłko")));
            var built = (TileBuilders.Tile) render.invoke(tile, overview);
            var elements = new ArrayList<VisualText>();
            readTile(built.getTileTimeline().getTimelineEntries().get(0).getLayout().getRoot(),
                elements, labels.getResources().getDisplayMetrics());
            var shown = elements.stream().map(VisualText::text).toList();
            int headline = switch (stage) {
                case "context" -> R.string.child_parent_reviewing;
                case "decision" -> R.string.child_parent_deciding;
                case "answered" -> R.string.answered;
                case "expired" -> R.string.child_plans;
                default -> R.string.child_parent_waiting;
            };
            if (!shown.contains(labels.getString(headline)) || !shown.contains("Jabłko") ||
                    shown.contains(labels.getString(R.string.child_decision_timer)) != (!expired && !answered) ||
                    shown.contains(labels.getString(R.string.open_request)) != answered ||
                    shown.contains(labels.getString(R.string.child_plans)) != expired ||
                    shown.contains("Anna") != claimed) {
                throw new AssertionError("Unexpected waiting tile (" + stage + "): " + shown);
            }
        }
    }

    private void verifyAdvisorPage(MealDecisionWatchActivity activity) throws Exception {
        Context labels = WatchLanguage.update(activity, "pl");
        field("localizedContext").set(activity, labels);
        Method render = MealDecisionWatchActivity.class.getDeclaredMethod(
            "renderAdvisorSuggestion", JSONObject.class);
        render.setAccessible(true);
        Method clear = MealDecisionWatchActivity.class.getDeclaredMethod("clearScreen");
        clear.setAccessible(true);
        var root = (View) field("root").get(activity);
        clear.invoke(activity);
        render.invoke(activity, new JSONObject().put("type", "insulinThenWait").put("minutes", 15));
        var content = new ArrayList<VisualText>();
        readApp(root, content);
        var shown = content.stream().map(VisualText::text).toList();
        if (!shown.contains(labels.getString(R.string.context_advisor_title)) ||
                !shown.contains("15 min") || !shown.contains(labels.getString(R.string.context_advisor_then_meal))) {
            throw new AssertionError("Missing saved advisor suggestion: " + shown);
        }
        Method page = MealDecisionWatchActivity.class.getDeclaredMethod("renderContextPage",
            int.class, String.class, String.class, JSONObject.class, JSONObject.class, JSONArray.class, int.class);
        page.setAccessible(true);
        int generation = field("requestGeneration").getInt(activity);
        page.invoke(activity, generation, null, "test", new JSONObject(),
            new JSONObject().put("advisorSuggestion",
                new JSONObject().put("type", "insulinThenWait").put("minutes", 180)), new JSONArray(), 5);
        int width = root.getWidth();
        int height = root.getHeight();
        root.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY));
        root.layout(root.getLeft(), root.getTop(), root.getLeft() + width, root.getTop() + height);
        for (String expected : List.of(labels.getString(R.string.context_advisor_title),
                labels.getString(R.string.context_advisor_bolus_wait), "180 min",
                labels.getString(R.string.context_advisor_then_meal))) {
            var matches = new ArrayList<View>();
            root.findViewsWithText(matches, expected, View.FIND_VIEWS_WITH_TEXT);
            var text = matches.stream().filter(view -> view instanceof TextView label &&
                expected.contentEquals(label.getText())).map(view -> (TextView) view).findFirst().orElseThrow();
            var visible = new Rect();
            if (text.getLayout() == null || !text.getLocalVisibleRect(visible) ||
                    visible.height() < text.getLayout().getHeight()) {
                throw new AssertionError("Advisor text is clipped: " + expected);
            }
        }
        clear.invoke(activity);
        render.invoke(activity, (Object) null);
        content.clear();
        readApp(root, content);
        if (content.stream().noneMatch(entry ->
                entry.text().equals(labels.getString(R.string.context_advisor_unavailable)))) {
            throw new AssertionError("Missing unavailable advisor state");
        }
    }

    private void verifyExtraSummary(MealDecisionWatchActivity activity, Context labels,
                                    View root, JSONObject meal) throws Exception {
        Method summary = MealDecisionWatchActivity.class.getDeclaredMethod(
            "renderChildSummary", String.class, JSONObject.class, boolean.class);
        summary.setAccessible(true);
        summary.invoke(activity, null, meal, true);
        var all = button(root, labels.getString(R.string.meal_summary_ate_all));
        var less = button(root, labels.getString(R.string.meal_summary_ate_less));
        if (all == null || less == null ||
            button(root, labels.getString(R.string.meal_summary_add_on)) != null) {
            throw new AssertionError("Extra summary must offer all or less and no second extra");
        }
        less.performClick();
        var content = new ArrayList<VisualText>();
        readApp(root, content);
        if (content.stream().noneMatch(text ->
                labels.getString(R.string.meal_summary_phone_required).equals(text.text()))) {
            throw new AssertionError("Eating less must continue on the phone");
        }
    }

    private Button button(View view, String text) {
        if (view.getVisibility() != View.VISIBLE) return null;
        if (view instanceof Button button && text.contentEquals(button.getText())) return button;
        if (view instanceof ViewGroup group) {
            for (int index = 0; index < group.getChildCount(); index++) {
                var match = button(group.getChildAt(index), text);
                if (match != null) return match;
            }
        }
        return null;
    }

    private Field field(String name) throws Exception {
        var field = MealDecisionWatchActivity.class.getDeclaredField(name);
        field.setAccessible(true);
        return field;
    }

    private void readApp(View view, List<VisualText> result) {
        if (view.getVisibility() != View.VISIBLE) return;
        if (view instanceof TextView text) {
            result.add(new VisualText(text instanceof Chronometer ? "<countdown>"
                : text.getText().toString(), Math.round(text.getTextSize()),
                text.getCurrentTextColor()));
        }
        if (view instanceof ViewGroup group) {
            for (int index = 0; index < group.getChildCount(); index++) {
                readApp(group.getChildAt(index), result);
            }
        }
    }

    private void readTile(LayoutElementBuilders.LayoutElement node, List<VisualText> result,
                          DisplayMetrics metrics) {
        if (node instanceof LayoutElementBuilders.Text text) {
            var font = text.getFontStyle();
            int size = Math.round(TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP, font.getSize().getValue(), metrics));
            result.add(new VisualText(text.getText().getDynamicValue() == null
                ? text.getText().getValue() : "<countdown>", size, font.getColor().getArgb()));
        }
        if (node instanceof LayoutElementBuilders.Box box) {
            for (var child : box.getContents()) readTile(child, result, metrics);
        }
        if (node instanceof LayoutElementBuilders.Column column) {
            for (var child : column.getContents()) readTile(child, result, metrics);
        }
        if (node instanceof LayoutElementBuilders.Row row) {
            for (var child : row.getContents()) readTile(child, result, metrics);
        }
    }
}
