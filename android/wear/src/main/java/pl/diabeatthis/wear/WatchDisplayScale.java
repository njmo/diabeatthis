package pl.diabeatthis.wear;

import android.content.Context;
import android.util.DisplayMetrics;

final class WatchDisplayScale {
    private static final float REFERENCE_DIAMETER = 192f;
    private final float pixelsPerUnit;
    private final float density;

    WatchDisplayScale(Context context) {
        DisplayMetrics display = context.getResources().getDisplayMetrics();
        pixelsPerUnit = Math.min(display.widthPixels, display.heightPixels) / REFERENCE_DIAMETER;
        density = display.density;
    }

    float pixelsPerUnit() {
        return pixelsPerUnit;
    }

    int px(float units) {
        return Math.round(units * pixelsPerUnit);
    }

    float pixelsAtFraction(float fraction) {
        return fraction * REFERENCE_DIAMETER * pixelsPerUnit;
    }

    float dpAtFraction(float fraction) {
        return pixelsAtFraction(fraction) / density;
    }

    float dp(float units) {
        return units * pixelsPerUnit / density;
    }
}
