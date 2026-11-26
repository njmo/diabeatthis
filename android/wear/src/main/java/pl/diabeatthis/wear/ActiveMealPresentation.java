package pl.diabeatthis.wear;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;

record ActiveMealPresentation(String title, String status, JSONObject progress, boolean canFinishEating, boolean readyToStart) {
    static final int WARNING_COLOR = 0xffffcf7f;
    static final float WAIT_CLOCK_FRACTION = .10f;
    static final int TITLE_SIZE = 11;
    static final int STATUS_SIZE = 11;
    static final int AMOUNTS_TITLE_SIZE = 10;
    static final int AMOUNTS_LABEL_SIZE = 9;
    static final int AMOUNTS_VALUE_SIZE = 14;
    static final int EATEN_BUTTON_WIDTH = 104;
    static final int EATEN_BUTTON_HEIGHT = 30;
    static final int ARC_HEIGHT = 28;
    static final int ARC_BOTTOM_PADDING = 8;

    static ActiveMealPresentation from(Context labels, JSONObject meal, boolean child) {
        boolean ready = isReadyToStart(meal);
        JSONObject progress = ready ? readyProgress(meal) : meal.optJSONObject("progress");
        int phase = progress == null ? 0 : progress.optBoolean("waitingForExtendedCarbs")
            ? R.string.active_meal_waiting_ecarbs : progressLabel(progress.optString("stage"));
        if (!child && phase == R.string.active_meal_waiting) phase = R.string.active_meal_caregiver_waiting;
        return new ActiveMealPresentation(splitTitle(meal.optString("mealName")),
            phase == 0 ? meal.optString("activeStatus") : labels.getString(phase), progress,
            meal.optBoolean("canComplete") && (progress == null ||
                "eating".equals(progress.optString("stage")) || "extra".equals(progress.optString("stage"))), ready);
    }

    static boolean isReadyToStart(JSONObject meal) {
        return meal.optString("activeStatus").isEmpty()
            && !meal.optString("acceptedDecision").isEmpty() && meal.optLong("bolusDueAtMs") == 0;
    }

    private static JSONObject readyProgress(JSONObject meal) {
        try {
            return new JSONObject()
                .put("count", "bolusWaitThenEat".equals(meal.optString("acceptedDecision")) ? 3 : 2)
                .put("index", -1);
        } catch (org.json.JSONException error) {
            throw new IllegalStateException(error);
        }
    }

    int heading() {
        return readyToStart ? R.string.meal_ready_heading : R.string.active_meal_heading;
    }

    boolean showsBolusAmounts() {
        return progress != null && ("bolus".equals(progress.optString("stage"))
            || waitsForExtendedCarbs())
            && progress.has("carbs");
    }

    boolean waitsForExtendedCarbs() {
        return progress != null && progress.optBoolean("waitingForExtendedCarbs");
    }

    int logoSize() {
        return waitUntil() > 0 ? 13 : showsBolusAmounts() ? 16 : 20;
    }

    int topPadding() {
        return waitUntil() > 0 ? 6 : showsBolusAmounts() ? 8 : 10;
    }

    int headingGap() {
        return waitUntil() > 0 ? 2 : showsBolusAmounts() ? 3 : 6;
    }

    int count() {
        return progress == null ? 0 : progress.optInt("count");
    }

    int index() {
        return progress == null ? 0 : progress.optInt("index");
    }

    /** Older phones only enabled Start eating through the wait deadline. */
    boolean canStartEating() {
        if (progress == null) return false;
        if (progress.has("canStartEating")) return progress.optBoolean("canStartEating");
        return waitUntil() > 0 && !waitsForExtendedCarbs();
    }

    long waitUntil() {
        return progress == null || !"waiting".equals(progress.optString("stage"))
            ? 0 : progress.optLong("waitUntilMs");
    }

    static String splitTitle(String name) {
        int colon = name.indexOf(':');
        if (colon <= 0 || name.substring(colon + 1).isBlank()) return name;
        return name.substring(0, colon + 1) + "\n" + name.substring(colon + 1).strip();
    }

    static int progressColor(JSONObject progress, int step) {
        int current = progress.optInt("index");
        if (step == current) return WatchPalette.ACCENT;
        JSONArray completed = progress.optJSONArray("completed");
        if (completed == null) return step < current ? 0xff809d75 : 0xff46574d;
        for (int i = 0; i < completed.length(); i++) {
            if (completed.optInt(i, -1) == step) return 0xff809d75;
        }
        return 0xff46574d;
    }

    private static int progressLabel(String stage) {
        return switch (stage) {
            case "bolus" -> R.string.active_meal_bolus;
            case "waiting" -> R.string.active_meal_waiting;
            case "eating" -> R.string.active_meal_eating;
            case "extra" -> R.string.active_meal_extra;
            default -> 0;
        };
    }

}
