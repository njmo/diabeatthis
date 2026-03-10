import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../core/domain/model/glucose.dart';

class GlucoseMiniChart extends ConsumerWidget {
  const GlucoseMiniChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glucose = ref.watch(glucoseWithLimitProvider(10));

    return glucose.when(
      data: (glucose) {
        return RepaintBoundary(
          child: CustomPaint(
            painter: _SlimGlucoseMiniChartPainter(glucose.reversed.toList()),
            size: Size.infinite,
          ),
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text('Błąd: $error'),
    );
  }
}

class _SlimGlucoseMiniChartPainter extends CustomPainter {
  final List<Glucose> values;

  _SlimGlucoseMiniChartPainter(this.values);

  Color _colorFor(int v) {
    if (v < 70 || v > 250) return const Color(0xFFE53935);
    if (v > 180) return const Color(0xFFFBC02D);
    return const Color(0xFF43A047);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final valuesList = values;
    if (valuesList.isEmpty) return;

    final data = valuesList.length <= 10
        ? valuesList
        : valuesList.sublist(valuesList.length - 10);

    final minVal = data.map((e) => e.sgv).reduce((a, b) => a < b ? a : b);
    final maxVal = data.map((e) => e.sgv).reduce((a, b) => a > b ? a : b);

    var minY = (minVal ).toDouble();
    var maxY = (maxVal ).toDouble();

    const minRange = 50.0;
    final range = maxY - minY;
    if (range < minRange) {
      final mid = (minY + maxY) / 2;
      minY = mid - minRange / 2;
      maxY = mid + minRange / 2;
    }

    double clampY(int v) => v.clamp(minY, maxY).toDouble();

    final topPad = size.height * 0.18;
    final bottomPad = size.height * 0.18;
    final h = size.height - topPad - bottomPad;
    final w = size.width;

    final dx = data.length <= 1 ? 0.0 : w / (data.length - 1);

    Offset p(int i) {
      final v = clampY(data[i].sgv);
      final t = (v - minY) / (maxY - minY); // 0..1
      final y = topPad + (1.0 - t) * h;
      return Offset(i * dx, y);
    }

    Paint segPaint(Color c) => Paint()
      ..color = c
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    for (var i = 0; i < data.length - 1; i++) {
      canvas.drawLine(
        p(i),
        p(i + 1),
        segPaint(_colorFor(data[i + 1].sgv)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SlimGlucoseMiniChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}
