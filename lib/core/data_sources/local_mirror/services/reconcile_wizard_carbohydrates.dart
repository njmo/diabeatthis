import '../../../../common/history/bolus_wizard_grouping.dart';
import '../../../domain/model/bolus_wizard.dart';
import '../../../domain/model/treat.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../drift/dao/local_mirror_dao.dart';
import '../../config/data_source_config.dart';
import '../history/local_treatments_history_repository.dart';
import '../mappers/bolus_wizard_drift_mapper.dart';
import '../mappers/treat_drift_mapper.dart';
import '../models/wizard_carbohydrate_component.dart';
import '../models/wizard_submission_evidence.dart';

/// Keeps calculator components inside their wizard, never as separate intakes.
class ReconcileWizardCarbohydrates {
  const ReconcileWizardCarbohydrates(this.dao);

  final LocalMirrorDao dao;

  Future<List<BolusWizard>> call(
    List<Treatment> batch,
    TreatmentsSource source,
  ) async {
    final times = batch.map((record) => record.createdAt).nonNulls.toList();
    if (times.isEmpty) return const [];
    const window = BolusWizardGrouping.carbSubmissionWindow;
    final start = times
        .reduce((a, b) => a.isBefore(b) ? a : b)
        .subtract(window);
    final end = times.reduce((a, b) => a.isAfter(b) ? a : b).add(window);
    // Two extra hops retain a leading component when examining trailing carbs.
    final contextStart = start.subtract(window * 2);
    final contextEnd = end.add(window * 2);
    final stored = await LocalTreatmentsHistoryRepository(
      dao,
    ).fetchTreatmentsBetween(contextStart, contextEnd);
    final wizards = await dao.getBolusWizardsBetween(contextStart, contextEnd);
    final attached = {
      for (final wizard in wizards)
        if (WizardSubmissionEvidence.fromJson(
              wizard.carbohydrateComponent,
            ).carbohydrates
            case final WizardCarbohydrateComponent component)
          wizard.createdAt: component,
    };
    final components = <int, WizardCarbohydrateComponent>{
      for (final component in attached.values)
        component.createdAt.millisecondsSinceEpoch: component,
      for (final row in await dao.getTreatsBetween(contextStart, contextEnd))
        row.createdAt: WizardCarbohydrateComponent.fromCompanion(
          row.toCompanion(true),
        ),
      for (final carbs in batch.whereType<Treat>())
        carbs.createdAt.millisecondsSinceEpoch:
            WizardCarbohydrateComponent.fromCompanion(
              carbs.toCompanion(source),
            ),
    };
    final carbsByTime = <int, Treat>{
      for (final component in components.values)
        component.createdAt.millisecondsSinceEpoch: component.treatment,
      for (final carbs in batch.whereType<Treat>())
        carbs.createdAt.millisecondsSinceEpoch: carbs,
    };
    final grouping = BolusWizardGrouping([
      ...stored.where((record) => record is! Treat),
      ...carbsByTime.values,
    ]);
    bool affected(DateTime time) => !time.isBefore(start) && !time.isAfter(end);

    // Clear old ownership first so edits and invalidations can restore an intake.
    for (final entry in attached.entries) {
      if (affected(entry.value.createdAt)) {
        await dao.clearWizardCarbohydrateComponent(
          DateTime.fromMillisecondsSinceEpoch(entry.key),
        );
      }
    }
    for (final carbs in carbsByTime.values) {
      if (!affected(carbs.createdAt)) continue;
      final owner = grouping.carbohydrateWizards[carbs];
      if (carbs.isValid && owner != null) {
        await dao.attachWizardCarbohydrateComponent(
          owner.createdAt,
          components[carbs.createdAt.millisecondsSinceEpoch]!,
        );
        await dao.deleteTreatByCreatedAt(carbs.createdAt);
      } else if (carbs.isValid) {
        await dao.upsertTreat(
          components[carbs.createdAt.millisecondsSinceEpoch]!.toCompanion(),
        );
      } else {
        await dao.deleteTreatByCreatedAt(carbs.createdAt);
      }
    }
    final previousComponents = {
      for (final wizard in wizards)
        wizard.createdAt: wizard.carbohydrateComponent,
    };
    return [
      for (final wizard in await dao.getBolusWizardsBetween(
        contextStart,
        contextEnd,
      ))
        if (previousComponents[wizard.createdAt] !=
            wizard.carbohydrateComponent)
          wizard.toDomain(),
    ];
  }
}
