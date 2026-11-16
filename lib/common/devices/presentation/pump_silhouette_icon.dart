import 'package:flutter/material.dart';

import '../insulin_pump_type.dart';

class PumpSilhouetteIcon extends StatelessWidget {
  final InsulinPumpType type;
  final double size;
  final Color? color;

  const PumpSilhouetteIcon({
    super.key,
    required this.type,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? const Color(0xFFFF9500); // Loop signature iOS orange

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PumpPainter(type: type, color: effectiveColor),
      ),
    );
  }
}

class _PumpPainter extends CustomPainter {
  final InsulinPumpType type;
  final Color color;

  _PumpPainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final solidPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case InsulinPumpType.omnipod:
        // Omnipod: Loop-style vertical solid silhouette with reservoir window cutout
        final podWidth = w * 0.62;
        final podHeight = h * 0.92;
        final podRect = Rect.fromCenter(
          center: center,
          width: podWidth,
          height: podHeight,
        );
        final outer = Path()
          ..addRRect(RRect.fromRectAndRadius(
            podRect,
            Radius.circular(podWidth * 0.36),
          ));

        // Window cutout (negative space in upper-middle of pod like Loop)
        final windowRect = Rect.fromCenter(
          center: Offset(center.dx, center.dy - podHeight * 0.12),
          width: podWidth * 0.44,
          height: podHeight * 0.22,
        );
        final windowPath = Path()
          ..addRRect(RRect.fromRectAndRadius(
            windowRect,
            Radius.circular(podWidth * 0.16),
          ));

        final pod = Path.combine(PathOperation.difference, outer, windowPath);
        canvas.drawPath(pod, solidPaint);
        break;

      case InsulinPumpType.ypsopump:
        // Ypsomed YpsoPump: Slim vertical rectangular pump with cartridge cutout
        final bodyRect = Rect.fromCenter(
          center: center,
          width: w * 0.56,
          height: h * 0.88,
        );
        final bodyPath = Path()
          ..addRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.14)));

        // Cartridge glass window (top cutout)
        final glassRect = Rect.fromLTWH(
          bodyRect.left + w * 0.09,
          bodyRect.top + h * 0.10,
          bodyRect.width - w * 0.18,
          h * 0.30,
        );
        final glassPath = Path()
          ..addRRect(RRect.fromRectAndRadius(glassRect, Radius.circular(w * 0.06)));

        // LED / button dot cutout (bottom)
        final dotPath = Path()
          ..addOval(
            Rect.fromCircle(
              center: Offset(center.dx, bodyRect.bottom - h * 0.18),
              radius: w * 0.07,
            ),
          );

        var ypso = Path.combine(PathOperation.difference, bodyPath, glassPath);
        ypso = Path.combine(PathOperation.difference, ypso, dotPath);
        canvas.drawPath(ypso, solidPaint);
        break;

      case InsulinPumpType.dana:
      case InsulinPumpType.medtronic:
      case InsulinPumpType.combo:
      default:
        // Traditional pump with screen cutout and reservoir screw cap
        final bodyRect = Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.54),
          width: w * 0.84,
          height: h * 0.68,
        );
        final bodyPath = Path()
          ..addRRect(RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.12)));

        // Screen cutout
        final screenRect = Rect.fromLTWH(
          bodyRect.left + w * 0.08,
          bodyRect.top + h * 0.12,
          bodyRect.width * 0.52,
          bodyRect.height * 0.42,
        );
        final screenPath = Path()
          ..addRRect(RRect.fromRectAndRadius(screenRect, Radius.circular(w * 0.04)));

        final pumpBody = Path.combine(PathOperation.difference, bodyPath, screenPath);
        canvas.drawPath(pumpBody, solidPaint);

        // Reservoir cap on top right
        final capRect = Rect.fromLTWH(
          bodyRect.right - w * 0.24,
          bodyRect.top - h * 0.10,
          w * 0.16,
          h * 0.11,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(capRect, Radius.circular(w * 0.04)),
          solidPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PumpPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
