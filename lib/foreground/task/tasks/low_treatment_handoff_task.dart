import 'dart:async';

import 'package:clock/clock.dart';

import '../../../core/domain/model/treatment_base.dart';
import '../../../features/low_treatment/data/providers/aaps_carbs_request_episode_store_provider.dart';
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
        final wake = context.eventWait<ForegroundEvent>();
        wake.future.ignore();
        var failed = false;
        try {
          final events = inbox.drain();
          final incoming = events
              .whereType<TreatmentAvailableEvent<Treatment>>()
              .map((event) => event.data)
              .toList();
          pendingEvents.addAll(incoming);
          final useCase = context.container.read(
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
            await _confirm(context, useCase, matches);
            nextRecovery = clock.now().add(recoveryInterval);
          }
          final deadline = context.durationWait(
            nextRecovery.difference(clock.now()),
          );
          try {
            await Future.any<void>([
              wake.future.then<void>((_) {}),
              deadline.future,
            ]);
          } finally {
            await deadline.cancel();
          }
        } on TaskCancelledException {
          rethrow;
        } catch (error) {
          failed = true;
          context.log(
            'Low treatment reconciliation failed: ${error.runtimeType}',
          );
        } finally {
          await wake.cancel();
        }
        if (failed) await context.waitForDuration(retryInterval);
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
