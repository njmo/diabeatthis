import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../data/providers/device_status_provider.dart';
import '../../data/providers/time_now_provider.dart';

import '../../data/utils/nightscout_utils.dart';
import 'glucose_custom_painter.dart';

class NightscoutPanel extends ConsumerWidget {
  const NightscoutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceStatusStream = ref.watch(deviceStatusStreamProvider);
    final timeNowStream = ref.watch(timeNowProvider);

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            deviceStatusStream.when(
              data: (status) {
                final lastUpdate = timeNowStream
                    .whenData((data) => data.difference(status.date))
                    .value;
                final bg = status.bg;
                final tick = parseTick(status.tick);

                final oldReading = lastUpdate!.inMinutes > 10;
                final bgColor = (oldReading)
                    ? Colors.black
                    : getColorForValue(bg);
                final trendIcon = iconForDirection(directionForTick(tick));

                final sign = tick > 0 ? '+' : '';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatAgo(lastUpdate),
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                      SizedBox(
                        width: 160,
                        height: 50,
                        child: GlucoseMiniChart(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Chip(
                            label: Text(
                              '$sign$tick mg/dl',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Chip(
                            avatar: Icon(
                              Icons.bakery_dining,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            label: Text(
                              '${status.cob.toStringAsFixed(2)}g',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Chip(
                            avatar: Icon(
                              Icons.vaccines,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            label: Text(
                              '${status.iob.toStringAsFixed(2)}U',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text('Błąd: $error'),
            ),
          ],
        ),
      ),
    );
  }
}
