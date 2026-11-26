import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../common/meal/calculator/calculator_evidence_snapshot.dart';
import '../../../common/meal/calculator/meal_calculator_request_controller_provider.dart';
import '../../../common/meal_advisor/remote/start_accepted_caregiver_meal.dart';
import '../../../common/treatments/calculator_submission.dart';
import '../../../core/domain/model/bolus_wizard.dart';
import '../../../core/domain/model/correction_bolus.dart';
import '../../../core/domain/model/extended_carb.dart';
import '../../../core/domain/model/manual_bolus.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../../../core/domain/model/treat.dart';
import '../../../core/domain/model/treatment_base.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../core/logger/logger.dart';
import '../../providers/calculator_submissions_provider.dart';
import '../../providers/latest_bolus_wizard_provider.dart';
import '../../providers/task_event_router_provider.dart';
import '../../synchronization/synchronization_cache_controller.dart';
import '../model/foreground_event.dart';
import 'calculator_submission_changed_event.dart';
import 'treatment_available_event.dart';

typedef ForegroundEventEmitter = void Function(ForegroundEvent event);

class TreatmentEventDispatcher with Logging {
  void dispatch({
    required ProviderContainer container,
    required ForegroundEventEmitter emitEvent,
    required Treatment treatment,
  }) => dispatchBatch(
    container: container,
    emitEvent: emitEvent,
    treatments: [treatment],
  );

  void dispatchBatch({
    required ProviderContainer container,
    required ForegroundEventEmitter emitEvent,
    required Iterable<Treatment> treatments,
  }) {
    final batch = treatments.toList();
    if (batch.isEmpty) return;
    final before = {
      for (final submission in container.read(calculatorSubmissionsProvider))
        submission.key.millisecondsSinceEpoch: submission,
    };
    final cache = container.read(calculatorSubmissionsProvider.notifier);
    // One malformed record must not stop the rest of the batch.
    for (final treatment in batch) {
      _isolated(
        'record ${treatment.runtimeType}',
        () => cache.record(treatment),
      );
    }
    final current = container.read(calculatorSubmissionsProvider);
    final changes = current
        .where((entry) => before[entry.key.millisecondsSinceEpoch] != entry)
        .toList();
    for (final submission in changes) {
      _isolated(
        'calculator submission',
        () => _dispatchSubmission(container, emitEvent, submission, before),
      );
    }

    final carbTimes = {
      for (final entry in current)
        if (entry.wizard.carbohydrateRecord case final carbs?)
          carbs.createdAt.millisecondsSinceEpoch,
    };
    final bolusTimes = {
      for (final entry in current)
        if (entry.delivery case final delivery?)
          delivery.createdAt.millisecondsSinceEpoch,
    };
    final corrections = <Treatment>[];
    for (final treatment in batch) {
      final isComponent = switch (treatment) {
        Treat() => carbTimes.contains(
          treatment.createdAt.millisecondsSinceEpoch,
        ),
        ManualBolus() => bolusTimes.contains(
          treatment.createdAt.millisecondsSinceEpoch,
        ),
        _ => false,
      };
      if (isComponent) continue;
      if (treatment is ExtendedCarb || treatment is Treat) {
        corrections.add(treatment);
      }
      if (!treatment.isValid) continue;
      _isolated('${treatment.runtimeType}', () {
        switch (treatment) {
          case CorrectionBolus():
            emitEvent(TreatmentAvailableEvent<CorrectionBolus>(treatment));
          case Treat():
            emitEvent(TreatmentAvailableEvent<Treat>(treatment));
          case ExtendedCarb():
            emitEvent(TreatmentAvailableEvent<ExtendedCarb>(treatment));
          case ManualBolus():
            emitEvent(TreatmentAvailableEvent<ManualBolus>(treatment));
          case TemporaryTarget():
            emitEvent(TreatmentAvailableEvent<TemporaryTarget>(treatment));
            _syncTemporaryTarget(container, treatment);
          default:
            break;
        }
      });
    }
    if (changes.isEmpty && corrections.isEmpty) return;
    final controller = container.read(mealCalculatorRequestControllerProvider);
    if (corrections.isEmpty) {
      unawaited(
        controller.observe(CalculatorEvidenceSnapshot(current, null).toJson()),
      );
      return;
    }
    for (final treatment in corrections) {
      unawaited(
        controller.observe(
          CalculatorEvidenceSnapshot(
            current,
            treatment is ExtendedCarb ? treatment : null,
            carbCorrection: treatment is Treat ? treatment : null,
          ).toJson(),
        ),
      );
    }
  }

  void _dispatchSubmission(
    ProviderContainer container,
    ForegroundEventEmitter emitEvent,
    CalculatorSubmission submission,
    Map<int, CalculatorSubmission> before,
  ) {
    emitEvent(CalculatorSubmissionChangedEvent(submission));
    if (!submission.isValid) return;
    final previous = before[submission.key.millisecondsSinceEpoch];
    final latest = container.read(latestBolusWizardProvider);
    final wizard = submission.wizard;
    final firstEntry = previous?.isValid != true;
    if ((firstEntry &&
            (latest == null || !wizard.createdAt.isBefore(latest.createdAt))) ||
        latest?.createdAt.isAtSameMomentAs(wizard.createdAt) == true) {
      container.read(latestBolusWizardProvider.notifier).update(wizard);
    }
    if (firstEntry) {
      emitEvent(TreatmentAvailableEvent<BolusWizard>(wizard));
      if (container.exists(databaseProvider)) {
        unawaited(
          container
              .read(startAcceptedMealFromCalculatorProvider)(wizard)
              .catchError(
                (Object error) => logW(
                  'Could not activate accepted meal from calculator: ${error.runtimeType}',
                ),
              ),
        );
      }
    }
  }

  void _isolated(String what, void Function() body) {
    try {
      body();
    } catch (error, stackTrace) {
      logE('Could not dispatch $what', error: error, stackTrace: stackTrace);
    }
  }

  void _syncTemporaryTarget(
    ProviderContainer container,
    TemporaryTarget target,
  ) {
    final cache = container.read(synchronizationCacheControllerProvider);
    cache.cacheTarget(target);

    if (container.read(appLifecycleProvider) != AppLifecycleState.resumed) {
      return;
    }

    final payload = TaskTargetSynchronization(data: target);
    container.read(taskEventRouterProvider).send(payload);
  }
}
