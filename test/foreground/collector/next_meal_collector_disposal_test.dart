import 'dart:async';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/collector/next_meal_collector.dart';
import 'package:diabeatthis/foreground/runtime/wait_handle.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  test(
    'cancelling an elapsed-time wait settles its future and removes its timer',
    () {
      fakeAsync((async) {
        final delay = WaitHandle.delay(const Duration(seconds: 1));
        var settled = false;
        delay.future.then((_) => settled = true);
        async.flushMicrotasks();
        expect(settled, isFalse);
        unawaited(delay.cancel());
        async.flushMicrotasks();
        expect(settled, isTrue);
        expect(async.nonPeriodicTimerCount, 0);
        unawaited(delay.cancel());
        async.flushMicrotasks();
        expect(async.nonPeriodicTimerCount, 0);
      });
    },
  );

  for (final hasCandidate in [false, true]) {
    test(
      'disposing collector releases waits without cancelling runtime; candidate=$hasCandidate',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        if (hasCandidate) {
          await db
              .into(db.meal)
              .insert(
                MealCompanion.insert(
                  name: 'Pending candidate',
                  plannedAt: DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch,
                ),
              );
        }
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        final harness = FakeRuntimeHarness(container: container);
        addTearDown(harness.dispose);
        final observedSnapshot = Completer<void>();
        final runtime = harness.runtimeContext;
        final collector = NextMealCollector();
        collector.start(
          CollectorContext(
            container: container,
            emitEvent: runtime.emitEvent,
            emitSignal: (key) {
              runtime.emitSignal(key);
              if (!observedSnapshot.isCompleted) observedSnapshot.complete();
            },
            waitForDuration: runtime.waitForDuration,
            waitForSignal: runtime.waitForSignal,
            durationWait: runtime.durationWait,
            signalWait: runtime.signalWait,
          ),
        );
        await observedSnapshot.future.timeout(const Duration(seconds: 1));
        // Let the collector consume the snapshot and enter its next wait.
        await Future<void>.delayed(Duration.zero);
        expect(harness.activeWaitersCount, greaterThan(0));
        await collector.dispose().timeout(const Duration(seconds: 1));
        expect(harness.activeWaitersCount, 0);
        expect(harness.runtimeContext.isCancelled, isFalse);
      },
    );
  }
}
