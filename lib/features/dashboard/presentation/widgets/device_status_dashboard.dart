import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_suggestion_card.dart';
import '../../data/providers/old_reading_provider.dart';
import '../../data/utils/nightscout_utils.dart';
import 'mini_glucose_chart.dart';

class DeviceStatusDashboard extends ConsumerWidget {
  final DeviceStatus deviceStatus;

  const DeviceStatusDashboard({super.key, required this.deviceStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oldReading = ref.watch(isReadingOldProvider.select((v) => v));
    final bg = deviceStatus.bg;
    final tick = parseTick(deviceStatus.tick);
    final bgColor = (oldReading) ? Colors.black : getColorForValue(bg);
    final trendIcon = iconForDirection(directionForTick(tick));

    final sign = tick > 0 ? '+' : '';

    return RepaintBoundary(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$bg',
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
          SizedBox(width: 160, height: 50, child: const MiniGlucoseChart()),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Chip(
                label: Text('$sign$tick mg/dl', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 5),
              Chip(
                avatar: const Icon(Icons.bakery_dining, size: 20),
                label: Text(
                  '${deviceStatus.cob.toStringAsFixed(2)}g',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 5),
              Chip(
                avatar: const Icon(Icons.vaccines, size: 20),
                label: Text(
                  '${deviceStatus.iob.toStringAsFixed(2)}U',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (deviceStatus.carbsReq > 0)
            LowTreatmentSuggestionCard(
              carbsReq: deviceStatus.carbsReq,
              carbsReqWithin: deviceStatus.carbsReqWithin,
              onAdd: () {},
            ),
        ],
      ),
    );
  }
}
