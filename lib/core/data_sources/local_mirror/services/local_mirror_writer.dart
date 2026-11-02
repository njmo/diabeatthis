import '../../../../common/history/bolus_wizard_grouping.dart';
import '../../../../common/meal/meal_bolus_delivery.dart';
import '../../../domain/model/bg_check.dart';
import '../../../domain/model/bolus_wizard.dart';
import '../../../domain/model/correction_bolus.dart';
import '../../../domain/model/device_status.dart';
import '../../../domain/model/extended_carb.dart';
import '../../../domain/model/glucose.dart';
import '../../../domain/model/manual_bolus.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treat.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../drift/dao/local_mirror_dao.dart';
import '../../../drift/models/wizard_identity_conflict.dart';
import '../../../logger/logger.dart';
import '../../config/data_source_config.dart';
import '../mappers/bolus_wizard_drift_mapper.dart';
import '../mappers/correction_bolus_drift_mapper.dart';
import '../mappers/device_status_drift_mapper.dart';
import '../mappers/extended_carb_drift_mapper.dart';
import '../mappers/glucose_drift_mapper.dart';
import '../mappers/manual_bolus_drift_mapper.dart';
import '../mappers/temporary_target_drift_mapper.dart';
import 'reconcile_wizard_carbohydrates.dart';

class LocalMirrorWriter with Logging {
  const LocalMirrorWriter(this._dao);

  final LocalMirrorDao _dao;

  Future<void> mirrorGlucose(Iterable<Glucose> readings) async {
    for (final reading in readings) {
      await _dao.upsertGlucoseReading(reading.toCompanion());
    }
  }

  Future<List<Treatment>> mirrorTreatments(
    Iterable<Treatment> treatments,
    TreatmentsSource source,
  ) => _dao.transaction(() async {
    final batch = treatments.toList();
    final accepted = <Treatment>[];
    final rejectedWizards = <BolusWizard>{};
    final invalidatedDeliveries = <ManualBolus>[];
    for (final treatment in batch) {
      switch (treatment) {
        case BgCheck():
          if (treatment.isValid) {
            await _dao.upsertSpotGlucose(treatment.reading.toCompanion());
          } else {
            await _dao.deleteSpotGlucose(
              treatment.reading.source.storageValue,
              treatment.reading.externalId!,
            );
          }
        case BolusWizard():
          try {
            final record = treatment.toCompanion(source);
            if (treatment.isValid) {
              final saved = await _dao.upsertBolusWizard(record);
              accepted.add(
                saved.toDomain().copyWith(localId: treatment.localId),
              );
            } else {
              await _dao.deleteBolusWizard(record);
              accepted.add(treatment);
            }
          } on WizardIdentityConflict catch (error) {
            rejectedWizards.add(treatment);
            logW('Wizard mirror conflict: ${error.message}');
          }
          continue;
        case TemporaryTarget():
          if (treatment.isValid) {
            await _dao.upsertTemporaryTarget(treatment.toCompanion(source));
          } else {
            await _dao.deleteTemporaryTargetByCreatedAt(treatment.createdAt);
          }
        case CorrectionBolus():
          if (treatment.isValid) {
            await _dao.upsertCorrectionBolus(treatment.toCompanion(source));
          } else {
            await _dao.deleteCorrectionBolusByCreatedAt(treatment.createdAt);
          }
        case ManualBolus():
          if (treatment.isValid) {
            await _dao.upsertManualBolus(treatment.toCompanion(source));
          } else {
            invalidatedDeliveries.addAll([
              treatment,
              for (final stored in await _dao.getManualBolusesBetween(
                treatment.createdAt,
                treatment.createdAt,
              ))
                stored.toDomain(),
            ]);
            await _dao.deleteManualBolusByCreatedAt(treatment.createdAt);
          }
        case Treat():
          // Decide after calculator and delivery records have been persisted.
          accepted.add(treatment);
          continue;
        case ExtendedCarb():
          if (treatment.isValid) {
            await _dao.upsertExtendedCarb(treatment.toCompanion(source));
          } else {
            await _dao.deleteExtendedCarbByCreatedAt(treatment.createdAt);
          }
        default:
          continue;
      }
      accepted.add(treatment);
    }
    final invalidatedWizards = <int, BolusWizard>{};
    final deliveryMargin =
        BolusWizardGrouping.carbSubmissionWindow +
        BolusWizardGrouping.deliveryClockTolerance;
    for (final delivery in invalidatedDeliveries) {
      if (!delivery.insulin.isFinite || delivery.insulin <= 0) continue;
      final calculators = await _dao.getBolusWizardsBetween(
        delivery.createdAt.subtract(deliveryMargin),
        delivery.createdAt.add(deliveryMargin),
      );
      for (final calculator in calculators) {
        if (!mealBolusDeliveryFollowsWizard(calculator.toDomain(), delivery)) {
          continue;
        }
        final marked = await _dao.markWizardDeliveryUnresolved(
          DateTime.fromMillisecondsSinceEpoch(calculator.createdAt),
        );
        if (marked != null) {
          invalidatedWizards[marked.createdAt] = marked.toDomain();
        }
      }
    }
    final rejectedComponents = <Treat>{};
    if (rejectedWizards.isNotEmpty) {
      for (final entry in BolusWizardGrouping(
        batch,
      ).carbohydrateWizards.entries) {
        if (!rejectedWizards.contains(entry.value)) continue;
        final component = entry.key;
        final nearby = await _dao.getBolusWizardsBetween(
          component.createdAt.subtract(
            BolusWizardGrouping.carbSubmissionWindow,
          ),
          component.createdAt.add(BolusWizardGrouping.carbSubmissionWindow),
        );
        // Keep unmatched intakes visible. Reject only evidence that could be
        // reassigned to another persisted calculator after the identity conflict.
        if (nearby.any(
          (wizard) =>
              wizard.carbs != null &&
              wizard.carbs!.isFinite &&
              (wizard.carbs! - component.carbs).abs() <= 0.001,
        )) {
          rejectedComponents.add(component);
        }
      }
    }
    accepted.removeWhere(rejectedComponents.contains);
    final reconciledBatch = batch
        .where(
          (record) =>
              !rejectedWizards.contains(record) &&
              !rejectedComponents.contains(record),
        )
        .toList();
    final changedWizards = {
      ...invalidatedWizards,
      for (final wizard in await ReconcileWizardCarbohydrates(_dao)(
        reconciledBatch,
        source,
      ))
        wizard.createdAt.millisecondsSinceEpoch: wizard,
    };
    final canonical = <Treatment>[];
    final emittedWizardTimes = <int>{};
    for (final treatment in accepted) {
      if (treatment is BolusWizard && treatment.isValid) {
        final time = treatment.createdAt.millisecondsSinceEpoch;
        final reconciled = changedWizards[time];
        emittedWizardTimes.add(time);
        canonical.add(
          reconciled?.copyWith(localId: treatment.localId) ?? treatment,
        );
      } else {
        canonical.add(treatment);
      }
    }
    // A separate carbohydrate frame can complete or revoke an existing
    // calculator submission. Publish its current persisted component as well.
    canonical.addAll(
      changedWizards.entries
          .where((entry) => !emittedWizardTimes.contains(entry.key))
          .map((entry) => entry.value.copyWith(localId: null)),
    );
    return canonical;
  });

  Future<void> mirrorDeviceStatuses(Iterable<DeviceStatus> statuses) async {
    for (final status in statuses) {
      await _dao.upsertDeviceStatus(status.toCompanion());
    }
  }
}
