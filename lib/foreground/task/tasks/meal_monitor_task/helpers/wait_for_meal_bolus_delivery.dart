import 'package:clock/clock.dart';

import '../../../../../common/meal/meal_bolus_coverage.dart';
import '../../../../../common/meal/meal_bolus_submission_candidates.dart';
import '../../../../../common/meal/meal_calculator_submission.dart';
import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../common/treatments/calculator_submission.dart';
import '../../../../../core/data_sources/config/data_source_config.dart';
import '../../../../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../../../../core/data_sources/local_mirror/services/local_mirror_writer.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/domain/model/manual_bolus.dart';
import '../../../../../core/domain/model/treat.dart';
import '../../../../../core/domain/model/treatment_base.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../event/internal/calculator_submission_changed_event.dart';
import '../../../../providers/calculator_submissions_provider.dart';
import '../../../../providers/meal_bolus_delivery_history_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';
import 'meal_bolus_delivery_changed.dart';

/// The calculator acknowledges an entry, not the start or end of delivery.
class WaitForMealBolusDelivery {
  const WaitForMealBolusDelivery();

  Future<CalculatorSubmission> call(
    RuntimeContext runtime,
    MealMonitorContext context,
    BolusWizard wizard, {
    bool Function(BolusWizard)? acceptsWizard,
  }) async {
    context.publishStatus(
      runtime,
      MealMonitoringPhase.waitingForDeliveryConfirmation,
    );
    final submissions = runtime.container.read(
      calculatorSubmissionsProvider.notifier,
    );
    if (!submissions.records.whereType<BolusWizard>().any(
      (record) => record.createdAt.isAtSameMomentAs(wizard.createdAt),
    )) {
      submissions.record(wizard);
    }
    final requestedWizard = wizard;
    while (true) {
      context.throwIfStopped(runtime);
      // Subscribe before reading persistent history so an arriving confirmation
      // cannot fall between the history read and the next event subscription.
      final changed = runtime.eventWait<CalculatorSubmissionChangedEvent>();
      // Cached confirmation can return before the wait is raced. Cancellation
      // still completes that unused subscription with an error.
      changed.future.ignore();
      ManualBolus? candidate;
      try {
        final submission = await _findConfirmedSubmission(
          runtime,
          context,
          requestedWizard,
          submissions,
          acceptsWizard,
        );
        context.throwIfStopped(runtime);
        if (submission == null) {
          final beforeRead = submissions.records.toList();
          final history = await runtime.interruptController.race(
            Future.any<List<Treatment>?>([
              runtime.container.read(mealBolusDeliveryHistoryProvider)(
                requestedWizard,
              ),
              changed.future.then((_) => null),
            ]),
          );
          context.throwIfStopped(runtime);
          if (history == null) continue;
          if (_recordHistory(
            runtime,
            submissions,
            history,
            beforeRead: beforeRead,
          )) {
            continue;
          }
        }
        if (submission != null) {
          wizard = submission.wizard;
          final confirmedDelivery = submission.delivery;
          candidate = confirmedDelivery;
          void requireCurrent() {
            if (!(acceptsWizard?.call(wizard) ?? true)) {
              throw const MealBolusDeliveryChanged();
            }
            _requireCurrent(submissions, submission);
          }

          requireCurrent();
          if (runtime.container.exists(databaseProvider)) {
            final db = runtime.container.read(databaseProvider);
            if (db.hasOpened) {
              final source = wizard.remoteSource == null
                  ? TreatmentsSource.aaps
                  : TreatmentsSource.cloud;
              // Persist this meal's accepted evidence even when bulk mirroring
              // is disabled, just as the workflow persists its calculator link.
              await db.transaction(() async {
                if (await mealBolusWizardAlreadyAssigned(db, wizard)) {
                  throw const MealBolusDeliveryChanged();
                }
                requireCurrent();
                final accepted = await LocalMirrorWriter(db.localMirrorDao)
                    .mirrorTreatments([
                      wizard,
                      if (wizard.carbohydrateRecord case final component?)
                        component,
                      if (confirmedDelivery != null) confirmedDelivery,
                    ], source);
                final canonical = accepted
                    .whereType<BolusWizard>()
                    .where(
                      (record) =>
                          record.createdAt.millisecondsSinceEpoch ==
                              wizard.createdAt.millisecondsSinceEpoch &&
                          _sameIdentity(record, wizard),
                    )
                    .firstOrNull;
                if (canonical == null) {
                  throw const MealBolusDeliveryChanged();
                }
                requireCurrent();
                _recordHistory(runtime, submissions, [canonical]);
                if (!CalculatorSubmission(
                  wizard: canonical,
                  delivery: confirmedDelivery,
                ).isComplete) {
                  throw const MealBolusDeliveryChanged();
                }
                requireCurrent();
              });
              context.throwIfStopped(runtime);
            }
          }
          requireCurrent();
          if (confirmedDelivery != null) {
            for (final changed in submissions.record(confirmedDelivery)) {
              runtime.emitEvent(CalculatorSubmissionChangedEvent(changed));
            }
          }
          requireCurrent();
          return submission;
        }
        // History can be refreshed independently of live broadcasts. A timeout
        // retries confirmation; it never marks an unconfirmed bolus as delivered.
        await runtime.any<void>([
          changed.map<void>((_) {}),
          runtime.durationWait(const Duration(seconds: 15)),
        ]);
      } on MealBolusDeliveryChanged {
        await _discardInvalidatedEvidence(
          runtime,
          submissions,
          wizard,
          candidate,
        );
      } finally {
        await changed.cancel();
      }
    }
  }

  Future<CalculatorSubmission?> _findConfirmedSubmission(
    RuntimeContext runtime,
    MealMonitorContext context,
    BolusWizard requested,
    CalculatorSubmissions submissions,
    bool Function(BolusWizard)? acceptsWizard,
  ) async {
    final db = runtime.container.exists(databaseProvider)
        ? runtime.container.read(databaseProvider)
        : null;
    if (db != null && db.hasOpened) {
      final now = clock.now();
      final saved = await db.localMirrorDao.getBolusWizardsBetween(
        requested.createdAt,
        now.isAfter(requested.createdAt) ? now : requested.createdAt,
      );
      context.throwIfStopped(runtime);
      _recordHistory(runtime, submissions, saved.map((row) => row.toDomain()));
    }
    for (final wizard in mealBolusSubmissionCandidates(
      requested,
      submissions.records,
      acceptsWizard: acceptsWizard,
    )) {
      if (wizard.createdAt.isAtSameMomentAs(requested.createdAt) &&
          !_sameIdentity(requested, wizard)) {
        continue;
      }
      var submission = resolveMealCalculatorSubmission(
        wizard,
        submissions.records,
      );
      if (db != null && db.hasOpened) {
        if (await mealBolusWizardAlreadyAssigned(db, wizard)) continue;
        submission = await readMealCalculatorSubmission(
          db,
          wizard,
          liveTreatments: submissions.records,
        );
        context.throwIfStopped(runtime);
      }
      if (submission.isComplete) {
        return submission;
      }
    }
    return null;
  }

  bool _recordHistory(
    RuntimeContext runtime,
    CalculatorSubmissions submissions,
    Iterable<Treatment> history, {
    Iterable<Treatment>? beforeRead,
  }) {
    var added = false;
    for (final record in history) {
      bool sameRecord(Treatment existing) =>
          existing.runtimeType == record.runtimeType &&
          existing.createdAt?.millisecondsSinceEpoch ==
              record.createdAt?.millisecondsSinceEpoch;
      var cached = submissions.records.where(sameRecord).firstOrNull;
      if (record is BolusWizard &&
          record.hasUnresolvedDelivery &&
          cached is BolusWizard &&
          !cached.hasUnresolvedDelivery &&
          _sameIdentity(record, cached)) {
        // This persisted blocker is monotonic. Enrich only that flag without
        // replacing a newer live calculator or carbohydrate correction.
        for (final changed in submissions.record(
          cached.copyWith(hasUnresolvedDelivery: true),
        )) {
          runtime.emitEvent(CalculatorSubmissionChangedEvent(changed));
        }
        cached = submissions.records.where(sameRecord).firstOrNull;
        added = true;
      }
      // Local rows do not replace live state. A source refresh may replace the
      // snapshot it started with, but never a correction or invalidation that
      // arrived while that refresh was running.
      if (cached != null &&
          (!cached.isValid ||
              beforeRead == null ||
              cached != beforeRead.where(sameRecord).firstOrNull)) {
        continue;
      }
      for (final changed in submissions.record(record)) {
        runtime.emitEvent(CalculatorSubmissionChangedEvent(changed));
      }
      added =
          added || submissions.records.where(sameRecord).firstOrNull != cached;
    }
    return added;
  }

  bool _sameIdentity(BolusWizard a, BolusWizard b) =>
      !(a.nightscoutObjectId != null &&
          b.nightscoutObjectId != null &&
          a.nightscoutObjectId != b.nightscoutObjectId) &&
      !(a.remoteSource != null &&
          b.remoteSource != null &&
          a.remoteSource != b.remoteSource) &&
      !(a.localId != null && b.localId != null && a.localId != b.localId);

  void _requireCurrent(
    CalculatorSubmissions submissions,
    CalculatorSubmission expected,
  ) {
    final wizard = expected.wizard;
    final current = submissions.records
        .whereType<BolusWizard>()
        .where((item) => item.createdAt.isAtSameMomentAs(wizard.createdAt))
        .firstOrNull;
    if (current != wizard ||
        resolveMealCalculatorSubmission(wizard, [
              if (expected.delivery case final delivery?) delivery,
              ...submissions.records,
            ]) !=
            expected) {
      throw const MealBolusDeliveryChanged();
    }
  }

  Future<void> _discardInvalidatedEvidence(
    RuntimeContext runtime,
    CalculatorSubmissions submissions,
    BolusWizard wizard,
    ManualBolus? delivery,
  ) async {
    if (!runtime.container.exists(databaseProvider)) return;
    final db = runtime.container.read(databaseProvider);
    if (!db.hasOpened) return;
    await db.transaction(() async {
      if (delivery != null) {
        final saved = await db.localMirrorDao.getManualBolusesBetween(
          delivery.createdAt,
          delivery.createdAt,
        );
        final latest = submissions.records
            .whereType<ManualBolus>()
            .where(
              (item) => item.createdAt.isAtSameMomentAs(delivery.createdAt),
            )
            .firstOrNull;
        if (latest != null &&
            !latest.isValid &&
            saved.length == 1 &&
            saved.single.createdAt ==
                delivery.createdAt.millisecondsSinceEpoch &&
            saved.single.externalId == delivery.externalId &&
            saved.single.insulin == delivery.insulin) {
          await LocalMirrorWriter(db.localMirrorDao).mirrorTreatments(
            [latest],
            wizard.remoteSource == null
                ? TreatmentsSource.aaps
                : TreatmentsSource.cloud,
          );
        }
      }
      final saved = await db.localMirrorDao.getBolusWizardsBetween(
        wizard.createdAt,
        wizard.createdAt,
      );
      final latest = submissions.records
          .whereType<BolusWizard>()
          .where((item) => item.createdAt.isAtSameMomentAs(wizard.createdAt))
          .firstOrNull;
      final previousComponent = wizard.carbohydrateRecord;
      if (latest != null &&
          latest.isValid &&
          previousComponent != null &&
          latest.carbohydrateRecord != previousComponent &&
          saved.length == 1) {
        final stored = saved.single.toDomain();
        final storedComponent = stored.carbohydrateRecord;
        final update = submissions.records
            .whereType<Treat>()
            .where(
              (record) => record.createdAt.isAtSameMomentAs(
                previousComponent.createdAt,
              ),
            )
            .firstOrNull;
        if (update != null &&
            update != previousComponent &&
            _sameIdentity(wizard, stored) &&
            stored.carbs == wizard.carbs &&
            stored.insulin == wizard.insulin &&
            storedComponent != null &&
            storedComponent.createdAt.isAtSameMomentAs(
              previousComponent.createdAt,
            ) &&
            storedComponent.externalId == previousComponent.externalId &&
            storedComponent.carbs == previousComponent.carbs) {
          // A live component invalidation may arrive after the outer commit
          // when bulk mirroring is off. Reconcile that exact newer component
          // so restart cannot reuse the evidence this attempt just persisted.
          await LocalMirrorWriter(db.localMirrorDao).mirrorTreatments(
            [latest, update],
            latest.remoteSource == null
                ? TreatmentsSource.aaps
                : TreatmentsSource.cloud,
          );
        }
      }
      if (latest != null && !latest.isValid && saved.length == 1) {
        final stored = saved.single.toDomain();
        if (_sameIdentity(wizard, stored) &&
            stored.carbs == wizard.carbs &&
            stored.insulin == wizard.insulin) {
          await db.localMirrorDao.deleteBolusWizard(
            latest.toCompanion(
              latest.remoteSource == null
                  ? TreatmentsSource.aaps
                  : TreatmentsSource.cloud,
            ),
          );
        }
      }
    });
  }
}
