import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/foreground/providers/device_status_value_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  test('clears stale device status after timer expiry', () {
    fakeAsync((async) {
      final start = DateTime(2026, 3, 23, 12, 0);

      withClock(Clock(() => start.add(async.elapsed)), () {
        final container = ProviderContainer();

        final notifier = container.read(deviceStatusValueProvider.notifier);

        notifier.update(
          DeviceStatus(
            id: 1,
            date: start,
            bg: 110,
            tick: '+12',
            iob: 0,
            cob: 0,
          ),
        );

        expect(container.read(deviceStatusValueProvider)?.bg, 110);

        async.elapse(const Duration(minutes: 6));
        async.flushMicrotasks();

        expect(container.read(deviceStatusValueProvider), isNull);

        container.dispose();
      });
    });
  });
}
