import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/foreground/providers/blood_sugar_value_provider.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

void main() {
  test('valid readings recover from a future-dated current sample', () {
    final now = DateTime(2026, 11, 3, 12);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    withClock(Clock.fixed(now), () {
      Glucose glucose(DateTime at, int value) => Glucose(
        externalId: '$value',
        source: GlucoseSource.aaps,
        date: at,
        sgv: value,
        direction: 'Flat',
      );
      final future = now.add(const Duration(minutes: 13));
      container
          .read(bloodSugarValueProvider.notifier)
          .update(glucose(future, 140));
      container
          .read(deviceStatusValueProvider.notifier)
          .update(
            testDeviceStatus(date: future, iob: 9, cob: 0, tick: '0', bg: 140),
          );
      container
          .read(bloodSugarValueProvider.notifier)
          .update(glucose(now, 100));
      container
          .read(deviceStatusValueProvider.notifier)
          .update(
            testDeviceStatus(date: now, iob: 1.25, cob: 0, tick: '0', bg: 100),
          );
      expect(container.read(bloodSugarValueProvider)?.sgv, 100);
      expect(container.read(deviceStatusValueProvider)?.iob, 1.25);
    });
  });
}
