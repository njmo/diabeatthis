import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/charts/draw_dashed_chart_line.dart';
import '../../../../common/presentation/charts/glucose_chart_timeline.dart';
import '../../../../common/presentation/dashboard/glucose_freshness.dart';
import '../../../../common/presentation/dashboard/glucose_freshness_provider.dart';
import '../../../../core/domain/model/aaps_prediction_snapshot.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../data/providers/blood_sugar_readings_list_provider.dart';
import '../../data/providers/time_now_provider.dart';

const _aapsColors = {
  'IOB': Color(0xFF3B82F6),
  'COB': Color(0xFFF59E0B),
  'UAM': Color(0xFF8B5CF6),
  'ZT': Color(0xFF64748B),
};

/// Actual CGM history over a fixed two-hour window ending at the current clock.
/// No interpolation across missing samples or fabricated future predictions.
class CompactLoopGlucoseChart extends ConsumerWidget {
  const CompactLoopGlucoseChart({
    super.key,
    this.height = 120,
    this.isDark = false,
    this.readings,
    this.aapsPredictionsJson,
  });
  final double height;
  final bool isDark;
  final List<Glucose>? readings;
  final String? aapsPredictionsJson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeNowProvider);
    final now = ref.watch(dashboardWallClockProvider)();
    final values = readings == null
        ? ref.watch(bloodSugarReadingsListProvider)
        : AsyncData(readings!);
    final dark = isDark || Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return values.when(
      data: (rows) {
        final ordered = rows.toList()..sort((a, b) => a.date.compareTo(b.date));
        final at = ordered.lastOrNull?.date;
        final stale =
            ref.watch(dashboardGlucoseStaleProvider(at)).asData?.value ??
            dashboardGlucoseIsStale(at, now);
        final decoded = AapsPredictionSnapshot.decode(aapsPredictionsJson);
        final expired =
            decoded != null &&
            ref
                    .watch(dashboardAapsExpiredProvider(decoded.calculatedAt))
                    .asData
                    ?.value ==
                true;
        final prediction = dashboardAapsPrediction(
          aapsPredictionsJson,
          now,
          stale: stale || expired,
        );
        final timeline = GlucoseChartTimeline(
          ordered,
          maxReadings: 241,
          windowEnd: now,
          window: const Duration(hours: 2),
        );
        return SizedBox(
          height: height,
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      key: ValueKey(
                        stale ? 'glucose-chart-stale' : 'glucose-chart-current',
                      ),
                      painter: DashboardGlucoseChartPainter(
                        timeline: timeline,
                        now: now,
                        isDark: dark,
                        stale: stale,
                        prediction: prediction,
                      ),
                    ),
                    if (timeline.values.isEmpty)
                      Center(
                        child: Text(
                          rows.isEmpty
                              ? context.lang.dashboardWaitingForHistory
                              : context.lang.beforeMealStale,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                  ],
                ),
              ),
              if (prediction != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(
                    key: const ValueKey('aaps-prediction-legend'),
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        Localizations.localeOf(context).languageCode == 'pl'
                            ? 'Prognoza AAPS'
                            : 'AAPS prediction',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                      for (final name in prediction.series.keys)
                        Text(
                          '━ $name',
                          style: TextStyle(
                            fontSize: 10,
                            color: _aapsColors[name],
                          ),
                        ),
                      const AapsPredictionHelp(),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final label in [
                    '−2h',
                    '−1h',
                    context.lang.dashboardActivityStartNow,
                    if (prediction != null) '+1h',
                    if (prediction != null) '+2h',
                  ])
                    if (label == context.lang.dashboardActivityStartNow)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A3FF).withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF00A3FF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      Text(label, style: TextStyle(fontSize: 10, color: muted)),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => SizedBox(
        height: height,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => SizedBox(
        height: height,
        child: Center(child: Text(context.lang.dashboardWaitingForHistory)),
      ),
    );
  }
}

/// Uses the standard anchored Material popup, including outside-tap dismissal.
class AapsPredictionHelp extends StatelessWidget {
  const AapsPredictionHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final polish = Localizations.localeOf(context).languageCode == 'pl';
    final explanations = polish
        ? const [
            'IOB · działanie aktywnej insuliny.',
            'COB · wchłanianie wpisanych węglowodanów.',
            'UAM · wzrost glukozy niewyjaśniony samą insuliną, np. po niewpisanym posiłku.',
            'ZT · scenariusz z czasowo wyłączoną insuliną bazową.',
          ]
        : const [
            'IOB · insulin on board: active insulin.',
            'COB · carbs on board: logged carbs being absorbed.',
            'UAM · unannounced meals: a glucose rise not explained by insulin alone.',
            'ZT · zero temp: a scenario with temporarily stopped basal insulin.',
          ];
    return PopupMenuButton<void>(
      tooltip: polish
          ? 'Co oznaczają skróty?'
          : 'What do these abbreviations mean?',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(maxWidth: 280),
      position: PopupMenuPosition.over,
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final explanation in explanations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(explanation),
                  ),
                Text(
                  polish
                      ? 'To scenariusze prognozy, nie odczyty sensora.'
                      : 'These are prediction scenarios, not sensor readings.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          Icons.help_outline,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

AapsPredictionSnapshot? dashboardAapsPrediction(
  String? encoded,
  DateTime now, {
  required bool stale,
}) {
  if (stale) return null;
  final prediction = AapsPredictionSnapshot.decode(encoded);
  if (prediction == null ||
      prediction.calculatedAt.isAfter(now) ||
      now.difference(prediction.calculatedAt) >= const Duration(minutes: 10)) {
    return null;
  }
  final hasFuture = prediction.series.values.any(
    (values) => prediction.calculatedAt
        .add(Duration(minutes: (values.length - 1) * 5))
        .isAfter(now),
  );
  return hasFuture ? prediction : null;
}

class DashboardGlucoseChartPainter extends CustomPainter {
  const DashboardGlucoseChartPainter({
    required this.timeline,
    required this.now,
    required this.isDark,
    required this.stale,
    this.prediction,
  });
  final GlucoseChartTimeline timeline;
  final DateTime now;
  final bool isDark, stale;
  final AapsPredictionSnapshot? prediction;

  Color colorFor(int value) {
    if (stale) {
      return isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    }
    if (value < 70 || value > 250) return const Color(0xFFEF4444);
    if (value > 180) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rows = timeline.values;
    final forecast = prediction;
    final forecastValues = <double>[];
    if (forecast != null) {
      for (final values in forecast.series.values) {
        for (var index = 0; index < values.length; index++) {
          final time = forecast.calculatedAt.add(Duration(minutes: index * 5));
          if (!time.isBefore(now.subtract(const Duration(minutes: 5))) &&
              !time.isAfter(now.add(const Duration(hours: 2)))) {
            forecastValues.add(values[index]);
          }
        }
      }
    }
    final allValues = [...rows.map((r) => r.sgv.toDouble()), ...forecastValues];
    final historyWidth = forecast == null ? size.width : size.width / 2;
    final minimum = math
        .min(70, allValues.isEmpty ? 70 : allValues.reduce(math.min) - 10)
        .toDouble();
    final maximum = math
        .max(180, allValues.isEmpty ? 180 : allValues.reduce(math.max) + 10)
        .toDouble();
    const pad = 6.0;
    final h = math.max(1.0, size.height - 2 * pad);
    double y(int value) =>
        pad + (1 - (value - minimum) / (maximum - minimum)) * h;
    Offset point(Glucose value) =>
        Offset(timeline.fractionAt(value.date) * historyWidth, y(value.sgv));
    final grid = (isDark ? Colors.white : Colors.black).withValues(alpha: .12);
    final reference = stale ? colorFor(100) : const Color(0xFF10B981);
    canvas.drawRect(
      Rect.fromLTRB(0, y(180), size.width, y(70)),
      Paint()..color = reference.withValues(alpha: isDark ? .045 : .035),
    );
    for (final value in [70, 180]) {
      drawDashedChartLine(
        canvas,
        Offset(0, y(value)),
        Offset(size.width, y(value)),
        Paint()
          ..color = grid
          ..strokeWidth = .8,
      );
    }
    drawDashedChartLine(
      canvas,
      Offset(historyWidth - 1, 0),
      Offset(historyWidth - 1, size.height),
      Paint()
        ..color = grid
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (forecast != null) {
      for (final entry in forecast.series.entries) {
        Offset forecastPoint(int index) {
          final time = forecast.calculatedAt.add(Duration(minutes: index * 5));
          return Offset(
            historyWidth +
                time.difference(now).inMilliseconds /
                    const Duration(hours: 2).inMilliseconds *
                    (size.width - historyWidth),
            y(entry.value[index].round()),
          );
        }

        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(historyWidth, 0, size.width, size.height),
        );
        for (var i = 1; i < entry.value.length; i++) {
          drawDashedChartLine(
            canvas,
            forecastPoint(i - 1),
            forecastPoint(i),
            Paint()
              ..color = _aapsColors[entry.key]!
              ..strokeWidth = 1.6,
          );
        }
        canvas.restore();
      }
    }
    for (final segment in timeline.segments) {
      if (segment.length > 1) {
        final points = segment.map(point).toList();
        final area = Path()..moveTo(points.first.dx, points.first.dy);
        for (final value in points.skip(1)) {
          area.lineTo(value.dx, value.dy);
        }
        area.lineTo(points.last.dx, size.height - pad);
        area.lineTo(points.first.dx, size.height - pad);
        area.close();
        canvas.drawPath(
          area,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorFor(
                  segment.last.sgv,
                ).withValues(alpha: isDark ? .24 : .16),
                colorFor(segment.last.sgv).withValues(alpha: 0),
              ],
            ).createShader(Offset.zero & size),
        );
      }
      for (var index = 1; index < segment.length; index++) {
        final first = point(segment[index - 1]), last = point(segment[index]);
        final path = Path()
          ..moveTo(first.dx, first.dy)
          ..lineTo(last.dx, last.dy);
        canvas.drawPath(
          path,
          Paint()
            ..color = colorFor(segment[index].sgv)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round,
        );
      }
      for (final reading in segment) {
        canvas.drawCircle(
          point(reading),
          2.3,
          Paint()..color = colorFor(reading.sgv),
        );
      }
    }
    if (rows.isNotEmpty) {
      final latest = rows.last;
      canvas.drawCircle(
        point(latest),
        6,
        Paint()..color = colorFor(latest.sgv).withValues(alpha: .2),
      );
      canvas.drawCircle(
        point(latest),
        3.5,
        Paint()..color = colorFor(latest.sgv),
      );
      canvas.drawCircle(
        point(latest),
        1.5,
        Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white,
      );
    }
    canvas.restore();
    for (final value in [70, 180]) {
      final label = TextPainter(
        text: TextSpan(
          text: '$value',
          style: TextStyle(
            fontSize: 9,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: .45,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(2, math.max(0, y(value) - label.height)));
    }
  }

  @override
  bool shouldRepaint(covariant DashboardGlucoseChartPainter oldDelegate) =>
      oldDelegate.timeline != timeline ||
      oldDelegate.now != now ||
      oldDelegate.isDark != isDark ||
      oldDelegate.stale != stale ||
      oldDelegate.prediction != prediction;
}
