import 'package:diabeatthis/common/history/bolus_wizard_grouping.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/treat.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../features/day_analysis/build_day_context_use_case_test.dart'
    show emptyMeals;
import 'wizard_carbs_persistence_test.dart' show calculatorSubmission;

void main() {
  test(
    'attached component prevents a later independent intake being hidden',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final writer = LocalMirrorWriter(db.localMirrorDao);
      final records = calculatorSubmission(carbDelay: -1000);
      final wizard = records.first as domain.BolusWizard;
      final independent = domain.Treat(
        externalId: 'independent',
        createdAt: wizard.createdAt.add(const Duration(seconds: 2)),
        carbs: 48,
      );
      await writer.mirrorTreatments(records, TreatmentsSource.aaps);
      await writer.mirrorTreatments([independent], TreatmentsSource.aaps);
      final history = LocalTreatmentsHistoryRepository(db.localMirrorDao);
      final stored = await history.fetchTreatmentsBetween(
        wizard.createdAt.subtract(const Duration(minutes: 1)),
        wizard.createdAt.add(const Duration(minutes: 1)),
      );
      expect(stored.whereType<domain.Treat>().toList(), [independent]);
      expect(BolusWizardGrouping(stored).isRelated(independent), isFalse);
      expect(
        stored.whereType<domain.BolusWizard>().single.carbohydrateRecord,
        records.last,
      );
      final day = await BuildDayContextUseCase(
        now: () => wizard.createdAt.add(const Duration(hours: 1)),
        loadGlucose: (_, _) async => [],
        loadTreatments: history.fetchTreatmentsBetween,
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      )(date: wizard.createdAt);
      expect(day.carbEntries, [independent]);
    },
  );
}
