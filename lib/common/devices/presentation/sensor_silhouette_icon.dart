import 'package:flutter/material.dart';

import '../cgm_sensor_type.dart';

class SensorSilhouetteIcon extends StatelessWidget {
  final CgmSensorType type;
  final double size;
  final Color? color;

  const SensorSilhouetteIcon({
    super.key,
    required this.type,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SensorPainter(type: type, color: effectiveColor),
      ),
    );
  }
}

class _SensorPainter extends CustomPainter {
  final CgmSensorType type;
  final Color color;

  _SensorPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final solidPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final patchPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case CgmSensorType.libre:
      case CgmSensorType.libre2:
      case CgmSensorType.libre3:
      case CgmSensorType.genericCgm:
        // FreeStyle Libre / Default CGM: Round sensor disc with center aperture cutout
        final radius = w * 0.44;
        final outer = Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius));
        final hole = Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius * 0.30));
        final disc = Path.combine(PathOperation.difference, outer, hole);
        canvas.drawPath(disc, solidPaint);
        break;

      case CgmSensorType.dexcomG7:
        // Dexcom G7: Compact circular sensor with center core detail
        final radius = w * 0.44;
        final outer = Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius));
        final innerRect = Rect.fromCenter(
          center: center,
          width: w * 0.38,
          height: h * 0.38,
        );
        final innerPath = Path()
          ..addRRect(RRect.fromRectAndRadius(innerRect, Radius.circular(w * 0.1)));
        final g7Body = Path.combine(PathOperation.difference, outer, innerPath);
        canvas.drawPath(g7Body, solidPaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(innerRect, Radius.circular(w * 0.1)),
          strokePaint,
        );
        break;

      case CgmSensorType.dexcomG6:
      case CgmSensorType.dexcomOne:
      case CgmSensorType.dexcom:
      default:
        // Dexcom G6: Oval adhesive patch with raised transmitter pill
        final patchRect = Rect.fromCenter(
          center: center,
          width: w * 0.90,
          height: h * 0.64,
        );
        final patchPath = Path()
          ..addRRect(RRect.fromRectAndRadius(patchRect, Radius.circular(h * 0.32)));
        canvas.drawPath(patchPath, patchPaint);
        canvas.drawPath(patchPath, strokePaint);

        // Transmitter pill
        final transRect = Rect.fromCenter(
          center: center,
          width: w * 0.52,
          height: h * 0.32,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(transRect, Radius.circular(h * 0.16)),
          solidPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SensorPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
