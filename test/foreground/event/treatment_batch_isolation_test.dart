import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/event/model/foreground_event.dart';
import 'package:diabeatthis/foreground/synchronization/synchronization_cache_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingCache extends SynchronizationCacheController {
  @override
  void cacheTarget(TemporaryTarget target) => throw StateError('broken');
}

void main() {
  test('a failing record does not stop events for the rest of the batch', () {
    final container = ProviderContainer(
      overrides: [
        synchronizationCacheControllerProvider.overrideWithValue(
          _FailingCache(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final at = DateTime(2026, 11, 26, 12);
    final events = <ForegroundEvent>[];

    TreatmentEventDispatcher().dispatchBatch(
      container: container,
      emitEvent: events.add,
      treatments: [
        TemporaryTarget(
          nightscoutId: 'target',
          createdAt: at,
          duration: 30,
          durationInMiliseconds: 30 * 60000,
          targetBottom: 100,
          targetTop: 110,
        ),
        ManualBolus(
          externalId: 'bolus',
          createdAt: at.add(const Duration(minutes: 1)),
          insulin: 1,
        ),
      ],
    );

    expect(
      events.whereType<TreatmentAvailableEvent<ManualBolus>>(),
      hasLength(1),
    );
  });
}
