import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../domain/use_cases/low_treatment_handoff_use_case.dart';
import '../repositories/low_treatment_handoff_repository.dart';
import '../repositories/recorded_low_treatment_repository.dart';

final lowTreatmentHandoffRepositoryProvider =
    Provider<LowTreatmentHandoffRepository>(
      (ref) => LowTreatmentHandoffRepository(ref.read(databaseProvider)),
    );

final lowTreatmentHandoffUseCaseProvider = Provider<LowTreatmentHandoffUseCase>(
  (ref) => LowTreatmentHandoffUseCase(
    handoffs: ref.watch(lowTreatmentHandoffRepositoryProvider),
    loadRecordedCarbs: (mealId) async => (await RecordedLowTreatmentRepository(
      ref.read(databaseProvider),
    ).fetchByMealId(mealId))?.netCarbsGrams,
    loadHistory: () => ref.read(treatmentsHistoryRepositoryProvider.future),
  ),
);
