import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../common/models/meal_wizard_relation_type.dart';
import '../domain/use_cases/link_recorded_meal_wizard_use_case.dart';

typedef MealWizardRecorder =
    Future<void> Function(
      BolusWizard wizard,
      int mealId,
      MealWizardRelationType type,
    );

final mealWizardRecorderProvider = Provider<MealWizardRecorder>((ref) {
  final useCase = LinkRecordedMealWizardUseCase(
    ref.watch(databaseProvider),
    loadSource: () async =>
        (await ref.read(dataSourceConfigProvider.future)).treatmentsSource,
  );
  return (wizard, mealId, type) => useCase(wizard, mealId, type: type);
});
