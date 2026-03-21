import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../data/providers/device_status_provider.dart';
import '../../data/providers/time_now_provider.dart';

import '../../data/utils/nightscout_utils.dart';
import 'device_status_dashboard.dart';
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

                final oldReading = lastUpdate!.inMinutes > 10;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RepaintBoundary(
                            child: Text(
                              formatAgo(lastUpdate),
                              style: textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (oldReading)
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                ref.invalidate(deviceStatusStreamProvider);
                                ref.invalidate(glucoseWithLimitProvider);
                              },
                            ),
                        ],
                      ),
                      DeviceStatusDashboard(deviceStatus: status),
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
