import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/aaps_carbs_request_episode_store_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_handoff_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/aaps_carbs_request_episode.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_handoff_match.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import 'package:diabeatthis/foreground/event/internal/aaps_carbs_request_acknowledged_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/low_treatment_handoff_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  final now = DateTime(2026, 9, 28, 12);
  test(
    'restart recovers match but completes only after durable monitor acknowledgement',
    () {
      fakeAsync((async) {
        withClock(Clock(() => now.add(async.elapsed)), () {
          final useCase = HandoffUseCaseFake(now);
          final store = EpisodeStoreFake(now);
          final container = ProviderContainer(
            overrides: [
              lowTreatmentHandoffUseCaseProvider.overrideWithValue(useCase),
              aapsCarbsRequestEpisodeStoreProvider.overrideWithValue(store),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          unawaited(
            const LowTreatmentHandoffTask()
                .run(harness.runtimeContext)
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                }),
          );
          async.flushMicrotasks();
          expect(useCase.completed, isEmpty);
          final event = harness.emittedEvents
              .whereType<AapsCarbsRequestAcknowledgedEvent>()
              .single;
          expect(event.episodeId, store.value.id);
          store.value = store.value.acknowledge(event.episodeId!);
          async.elapse(const Duration(minutes: 1));
          harness.dispatchTick(now.add(async.elapsed));
          async.flushMicrotasks();
          expect(useCase.completed, [1]);
          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    },
  );

  test(
    'live carbohydrate events are reconciled without glucose or a local mirror',
    () {
      fakeAsync((async) {
        withClock(Clock(() => now.add(async.elapsed)), () {
          final useCase = HandoffUseCaseFake(now)..matches = [];
          final container = ProviderContainer(
            overrides: [
              lowTreatmentHandoffUseCaseProvider.overrideWithValue(useCase),
            ],
          );
          final harness = FakeRuntimeHarness(container: container);
          unawaited(
            const LowTreatmentHandoffTask()
                .run(harness.runtimeContext)
                .catchError((Object error) {
                  if (error is! TaskCancelledException) throw error;
                }),
          );
          async.flushMicrotasks();
          final treat = Treat(externalId: 'remote', createdAt: now, carbs: 10);
          harness.dispatchEvent(TreatmentAvailableEvent<Treat>(treat));
          async.flushMicrotasks();
          expect(useCase.live, [treat]);
          harness.cancel();
          async.flushMicrotasks();
          container.dispose();
        });
      });
    },
  );
}

class HandoffUseCaseFake extends Fake implements LowTreatmentHandoffUseCase {
  HandoffUseCaseFake(DateTime at)
    : matches = [
        LowTreatmentHandoffMatch(
          mealId: 1,
          suggestionAt: at,
          treatAt: at,
          treatExternalId: 'remote',
        ),
      ];
  List<LowTreatmentHandoffMatch> matches;
  final completed = <int>[];
  final live = <Treat>[];
  @override
  Future<List<LowTreatmentHandoffMatch>> reconcile({
    required DateTime now,
    List<Treatment> liveTreatments = const [],
  }) async {
    live.addAll(liveTreatments.whereType<Treat>());
    return matches;
  }

  @override
  Future<void> markCompleted(int mealId) async {
    completed.add(mealId);
    matches = [];
  }
}

class EpisodeStoreFake extends Fake implements AapsCarbsRequestEpisodeStore {
  EpisodeStoreFake(DateTime at)
    : value = const AapsCarbsRequestEpisode.empty()
          .acceptStatus(at, 10)
          .start('${at.microsecondsSinceEpoch}:remote');
  AapsCarbsRequestEpisode value;
  @override
  Future<AapsCarbsRequestEpisode> load() async => value;
}
