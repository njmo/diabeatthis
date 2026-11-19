import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/dashboard/data/providers/time_now_provider.dart';
import 'glucose_freshness.dart';

final dashboardWallClockProvider = Provider<DateTime Function()>(
  (ref) => clock.now,
);

final dashboardAapsExpiredProvider = StreamProvider.autoDispose
    .family<bool, DateTime>((ref, calculatedAt) {
      ref.watch(timeNowProvider);
      final now = ref.watch(dashboardWallClockProvider)();
      final remaining = calculatedAt
          .add(const Duration(minutes: 10))
          .difference(now);
      final events = StreamController<bool>();
      Timer? deadline;
      events.onListen = () {
        events.add(remaining <= Duration.zero);
        if (remaining > Duration.zero) {
          deadline = Timer(remaining, () => events.add(true));
        }
      };
      ref.onDispose(() {
        deadline?.cancel();
        unawaited(events.close());
      });
      return events.stream;
    });

/// Expires at the sample's deadline even between the regular minute ticks.
final dashboardGlucoseStaleProvider = StreamProvider.autoDispose
    .family<bool, DateTime?>((ref, measuredAt) {
      ref.watch(timeNowProvider);
      final now = ref.watch(dashboardWallClockProvider)();
      final stale = dashboardGlucoseIsStale(measuredAt, now);
      final events = StreamController<bool>();
      Timer? deadline;
      events.onListen = () {
        events.add(stale);
        if (!stale) {
          deadline = Timer(
            measuredAt!.add(dashboardGlucoseFreshness).difference(now),
            () => events.add(true),
          );
        }
      };
      ref.onDispose(() {
        deadline?.cancel();
        unawaited(events.close());
      });
      return events.stream;
    });
