import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/domain/model/glucose.dart';
import '../../data/providers/time_now_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'glucose_custom_painter.dart';

class GlucoseDashboard extends ConsumerWidget {
  const GlucoseDashboard({super.key, required this.glucose});

  final Glucose glucose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeNow = ref.watch(timeNowProvider).value;
    final lastUpdate = timeNow?.difference(glucose.date);
    final oldReading = (lastUpdate?.inMinutes ?? 0) > 10;
    final bgColor = oldReading ? Colors.black : getColorForValue(glucose.sgv);
    final trendIcon = iconForDirection(glucose.direction);

    return RepaintBoundary(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${glucose.sgv}',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 86,
                  fontWeight: FontWeight.w700,
                  color: bgColor,
                ),
              ),
              const SizedBox(width: 12),
              Icon(trendIcon, size: 66, color: bgColor),
            ],
          ),
          const SizedBox(width: 160, height: 50, child: GlucoseMiniChart()),
        ],
      ),
    );
  }
}
