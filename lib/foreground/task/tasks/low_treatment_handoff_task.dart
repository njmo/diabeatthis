import 'dart:async';

import 'package:clock/clock.dart';

import '../../../common/history/bolus_wizard_grouping.dart';
import '../../../core/domain/model/treatment_base.dart';
import '../../../features/low_treatment/data/providers/aaps_carbs_request_episode_store_provider.dart';
import '../../../features/low_treatment/data/providers/low_treatment_aaps_provider.dart';
import '../../../features/low_treatment/data/providers/low_treatment_handoff_provider.dart';
import '../../../features/low_treatment/domain/models/low_treatment_handoff_match.dart';
import '../../../features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import '../../event/internal/aaps_carbs_request_acknowledged_event.dart';
import '../../event/internal/treatment_available_event.dart';
import '../../event/model/foreground_event.dart';
import '../../runtime/task_cancelled_exception.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

/// Reconciles persisted handoffs independently of glucose monitoring readiness.
class LowTreatmentHandoffTask extends WorkflowTask {
  const LowTreatmentHandoffTask();
  static const recoveryInterval = Duration(minutes: 1);
  static const retryInterval = Duration(seconds: 30);

  @override
  Future<void> run(RuntimeContext context) async {
    final inbox = context.openEventInbox<ForegroundEvent>();
    final pendingEvents = <Treatment>[];
    var nextRecovery = clock.now();
    try {
      while (!context.isCancelled) {
        var failed = false;
        try {
          await context.withWaitScope((scope) async {
            // Subscribe before asynchronous history reads; the inbox retains events.
            final wake = scope.eventWait<ForegroundEvent>();
            wake.future.ignore();
            final events = inbox.drain();
            final incoming = events
                .whereType<TreatmentAvailableEvent<Treatment>>()
                .map((event) => event.data)
                .toList();
            pendingEvents.addAll(incoming);
            final useCase = scope.container.read(
              lowTreatmentHandoffUseCaseProvider,
            );
            pendingEvents.removeWhere(
              (event) =>
                  event.createdAt == null ||
                  event.createdAt!.isBefore(
                    clock.now().subtract(const Duration(minutes: 10)),
                  ),
            );
            if (incoming.isNotEmpty || !clock.now().isBefore(nextRecovery)) {
              final matches = await useCase.reconcile(
                now: clock.now(),
                liveTreatments: List.of(pendingEvents),
              );
              await _confirm(scope, useCase, matches);
              nextRecovery = clock.now().add(
                incoming.isNotEmpty
                    ? BolusWizardGrouping.carbSubmissionWindow +
                          const Duration(seconds: 1)
                    : recoveryInterval,
              );
            }
            await scope.any<void>([
              wake.map<void>((_) {}),
              scope.wallClockWaitUntilHandle(nextRecovery),
            ]);
          });
        } on TaskCancelledException {
          rethrow;
        } catch (error) {
          failed = true;
          context.log(
            'Low treatment reconciliation failed: ${error.runtimeType}',
          );
        }
        if (failed) {
          await context.withWaitScope(
            (scope) => scope.any<void>([
              scope.wallClockWaitUntilHandle(clock.now().add(retryInterval)),
            ]),
          );
        }
      }
    } finally {
      inbox.close();
    }
  }

  Future<void> _confirm(
    RuntimeContext context,
    LowTreatmentHandoffUseCase useCase,
    List<LowTreatmentHandoffMatch> matches,
  ) async {
    for (final match in matches) {
      await context.container.read(confirmLowTreatmentAapsUseCaseProvider)(
        match.mealId,
      );
      final suggestionAt = match.suggestionAt;
      if (suggestionAt == null) {
        await useCase.markCompleted(match.mealId);
        continue;
      }
      final episode = await context.container
          .read(aapsCarbsRequestEpisodeStoreProvider)
          .load();
      if (episode.matchesSuggestionAt(suggestionAt)) {
        if (episode.acknowledged) {
          await useCase.markCompleted(match.mealId);
        } else {
          // The monitor remains the single writer of its persisted episode.
          context.emitEvent(
            AapsCarbsRequestAcknowledgedEvent(episodeId: episode.id),
          );
        }
      } else if (episode.lastAcceptedStatusAt != null &&
          !episode.lastAcceptedStatusAt!.isBefore(suggestionAt)) {
        // A withdrawn or newer request must not be acknowledged by this meal.
        await useCase.markCompleted(match.mealId);
      }
    }
  }
}
