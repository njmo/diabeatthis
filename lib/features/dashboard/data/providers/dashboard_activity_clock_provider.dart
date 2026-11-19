import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../activity/domain/activity_schedule_time.dart';
import 'time_now_provider.dart';

/// Adds the preparation and start boundaries to the dashboard's sampled clock.
final dashboardActivityClockProvider = Provider.autoDispose
    .family<DateTime, DateTime?>((ref, start) {
      final sampled = ref.watch(timeNowProvider).asData?.value ?? clock.now();
      if (start == null || !start.isAfter(sampled)) return sampled;

      return ref
              .watch(_activityBoundariesProvider((sampled, start)))
              .asData
              ?.value ??
          sampled;
    });

final _activityBoundariesProvider = StreamProvider.autoDispose
    .family<DateTime, (DateTime, DateTime)>((ref, times) {
      final (sampled, start) = times;
      final preparation = start.subtract(activityPreparationLeadTime);

      return Stream.multi((updates) {
        final preparationTimer = preparation.isAfter(sampled)
            ? Timer(
                preparation.difference(sampled),
                () => updates.addSync(preparation),
              )
            : null;
        final startTimer = Timer(start.difference(sampled), () {
          updates.addSync(start);
          updates.closeSync();
        });
        updates.onCancel = () {
          preparationTimer?.cancel();
          startTimer.cancel();
        };
      });
    });
