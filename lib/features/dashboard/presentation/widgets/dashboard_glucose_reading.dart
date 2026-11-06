import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/glucose.dart';
import 'mini_glucose_chart.dart';

class DashboardGlucoseReading extends StatelessWidget {
  const DashboardGlucoseReading({
    super.key,
    required this.value,
    required this.color,
    required this.trendIcon,
    this.change,
    this.readings,
  });

  final int? value;
  final Color color;
  final IconData? trendIcon;
  final String? change;
  final List<Glucose>? readings;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value?.toString() ?? '??',
              style: GoogleFonts.nunito(
                fontSize: 86,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (trendIcon != null || change != null) const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trendIcon != null) Icon(trendIcon, size: 56, color: color),
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
      SizedBox(
        height: 94,
        width: 296,
        child: MiniGlucoseChart(readings: readings),
      ),
      const SizedBox(height: 12),
    ],
  );
}
