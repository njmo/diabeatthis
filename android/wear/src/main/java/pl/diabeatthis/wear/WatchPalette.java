package pl.diabeatthis.wear;

import android.graphics.drawable.GradientDrawable;

final class WatchPalette {
    static final int BACKGROUND = 0xff131c17;
    static final int SURFACE = 0xff26372e;
    static final int OUTLINE = 0xff52634e;
    static final int ON_SURFACE = 0xfff1f6f0;
    static final int MUTED = 0xffb4c3b7;
    static final int ACCENT = 0xffcaed9e;
    static final int GRADIENT_TOP = 0xff2b3b2f;
    static final int GRADIENT_MIDDLE = 0xff1c2820;

    static GradientDrawable gradient(float radius) {
        var gradient = new GradientDrawable();
        gradient.setGradientType(GradientDrawable.RADIAL_GRADIENT);
        gradient.setGradientCenter(.5f, .16f);
        gradient.setGradientRadius(radius);
        gradient.setColors(new int[] {GRADIENT_TOP, GRADIENT_MIDDLE, BACKGROUND});
        return gradient;
    }

    private WatchPalette() {}
}
