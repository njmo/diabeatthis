import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../common/l10n/language.dart';
import 'mini_glucose_chart.dart';

class DashboardGlucoseReading extends StatelessWidget {
  const DashboardGlucoseReading({
    super.key,
    required this.value,
    required this.color,
    required this.trendIcon,
    this.change,
  });

  final int value;
  final Color color;
  final IconData trendIcon;
  final String? change;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: GoogleFonts.nunito(
                fontSize: 86,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(trendIcon, size: 56, color: color),
                if (change != null)
                  Semantics(
                    label: '${context.lang.dashboardGlucoseChange}: $change',
                    excludeSemantics: true,
                    child: Text(
                      change!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 94, width: 296, child: MiniGlucoseChart()),
      const SizedBox(height: 12),
    ],
  );
}
