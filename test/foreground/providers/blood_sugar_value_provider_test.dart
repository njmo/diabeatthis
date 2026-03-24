import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/foreground/providers/blood_sugar_value_provider.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clears stale glucose after timer expiry', () {
    fakeAsync((async) {
      final start = DateTime(2026, 3, 23, 12, 0);

      withClock(
        Clock(() => start.add(async.elapsed)),
            () {
          final container = ProviderContainer();

          final notifier = container.read(
            bloodSugarValueProvider.notifier,
          );

          notifier.update(
            Glucose(
              id: 1,
              date: start,
              sgv: 110,
              direction: 'Flat',
            ),
          );

          expect(container.read(bloodSugarValueProvider)?.sgv, 110);

          async.elapse(const Duration(minutes: 6));
          async.flushMicrotasks();

          expect(container.read(bloodSugarValueProvider), isNull);

          container.dispose();
        },
      );
    });
  });
}