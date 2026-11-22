package pl.diabeatthis.wear;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.view.View;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.json.JSONArray;

final class MealHistoryChart extends View {
    private record Sample(long time, double value) {}

    private final List<Sample> samples = new ArrayList<>();
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Path line = new Path();
    private final RectF frame = new RectF();
    private final DashPathEffect dashes;
    private final long start;
    private final long end;
    private final int color;
    private final boolean stepped;
    private final float scale;

    MealHistoryChart(Context context, JSONArray data, long start, long end,
                     int color, boolean stepped, String label) {
        super(context);
        this.start = start;
        this.end = end;
        this.color = color;
        this.stepped = stepped;
        scale = new WatchDisplayScale(context).pixelsPerUnit();
        dashes = new DashPathEffect(new float[] {2.5f * scale, 2.5f * scale}, 0);
        setContentDescription(label);
        for (int i = 0; i < data.length(); i++) {
            JSONArray row = data.optJSONArray(i);
            if (row == null) continue;
            long time = row.optLong(0);
            double value = row.optDouble(1);
            if (time >= start && time <= end && Double.isFinite(value)) {
                samples.add(new Sample(time, value));
            }
        }
        samples.sort(Comparator.comparingLong(Sample::time));
    }

    boolean hasSamples() {
        return !samples.isEmpty();
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        if (!hasSamples() || end <= start) return;

        frame.set(5 * scale, scale, getWidth() - 5 * scale, getHeight() - scale);
        if (frame.width() <= 2 * scale || frame.height() <= 2 * scale) return;
        double low = samples.get(0).value();
        double high = low;
        for (Sample sample : samples) {
            low = Math.min(low, sample.value());
            high = Math.max(high, sample.value());
        }
        if (low == high) {
            low -= 1;
            high += 1;
        }

        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(.8f * scale);
        paint.setColor(0xff4b5b51);
        canvas.drawRect(frame, paint);
        canvas.drawLine(frame.left, frame.centerY(), frame.right, frame.centerY(), paint);

        float startX = frame.left + 5 * scale;
        float endX = frame.right - 6 * scale;
        paint.setColor(0xff9fb0a3);
        paint.setPathEffect(dashes);
        canvas.drawLine(endX, frame.top + scale, endX, frame.bottom - scale, paint);
        paint.setPathEffect(null);

        float top = frame.top + frame.height() * .13f;
        float plotHeight = frame.height() * .74f;
        line.rewind();
        float x = startX;
        float y = frame.centerY();
        for (int i = 0; i < samples.size(); i++) {
            Sample sample = samples.get(i);
            float nextX = startX + (endX - startX) * (sample.time() - start) / (end - start);
            float nextY = top + plotHeight * (float) ((high - sample.value()) / (high - low));
            if (i == 0) {
                line.moveTo(nextX, nextY);
            } else {
                if (stepped) line.lineTo(nextX, y);
                line.lineTo(nextX, nextY);
            }
            x = nextX;
            y = nextY;
        }
        paint.setColor(color);
        paint.setStrokeCap(Paint.Cap.ROUND);
        paint.setStrokeJoin(Paint.Join.ROUND);
        paint.setStrokeWidth(2 * scale);
        if (samples.size() == 1) {
            paint.setStyle(Paint.Style.FILL);
            canvas.drawCircle(x, y, 1.6f * scale, paint);
        } else {
            canvas.drawPath(line, paint);
        }
    }
}
