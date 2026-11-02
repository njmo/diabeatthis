import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/data/providers/device_status_ui_provider.dart';
import '../../features/dashboard/data/providers/time_now_provider.dart';
import '../../features/dashboard/data/utils/nightscout_utils.dart';
import '../../foreground/providers/blood_sugar_value_provider.dart';
import '../l10n/language.dart';

/// A compact live reading using the same sources and trend icons as the dashboard.
class CurrentGlucoseSummary extends ConsumerWidget {
  const CurrentGlucoseSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceStatusUiProvider);
    final glucose = ref.watch(bloodSugarValueProvider);
    final now = ref.watch(timeNowProvider).value ?? clock.now();
    final useGlucose =
        glucose != null &&
        (device == null || !glucose.date.isBefore(device.date));
    final value = useGlucose ? glucose.sgv : device?.bg;
    final date = useGlucose ? glucose.date : device?.date;
    final age = date == null ? null : now.difference(date);
    final stale =
        age == null || age.isNegative || age >= const Duration(minutes: 10);
    final tick = num.tryParse(device?.tick.trim().replaceAll(',', '.') ?? '');
    final direction = useGlucose
        ? glucose.direction
        : tick == null
        ? null
        : directionForTick(tick.toInt());
    final theme = Theme.of(context);
    final color = value == null || stale
        ? theme.colorScheme.onSurfaceVariant
        : getColorForValue(value);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.water_drop_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.lang.mealReviewLast,
                    style: theme.textTheme.labelMedium,
                  ),
                  if (value == null || value <= 0 || date == null)
                    Text(context.lang.dayMissingGlucose)
                  else ...[
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$value ${context.lang.dashboardGlucoseUnit}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: color,
                          ),
                        ),
                        Icon(
                          iconForDirection(direction),
                          color: color,
                          size: 28,
                        ),
                      ],
                    ),
                    Text(
                      [
                        if (!age!.isNegative) formatAgo(age),
                        if (stale) context.lang.beforeMealStale,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
