import '../../../common/identifiers/create_uuid.dart';
import '../../../core/data_sources/nightscout/helpers/nightscout_delivery_key.dart';
import '../data/repositories/low_treatment_upload_repository.dart';
import '../domain/models/recorded_low_treatment.dart';
import 'nightscout_low_treatment_settings.dart';

class RegisterLowTreatmentUploadUseCase {
  const RegisterLowTreatmentUploadUseCase({
    required this.repository,
    required this.loadSettings,
    required this.loadRecorded,
  });
  final LowTreatmentUploadRepository repository;
  final Future<NightscoutLowTreatmentSettings> Function() loadSettings;
  final Future<RecordedLowTreatment?> Function(int) loadRecorded;

  Future<void> call(int mealId) async {
    final settings = await loadSettings();
    if (!settings.enabled) return;
    if (settings.token.trim().isEmpty) {
      throw StateError('Nightscout upload token required');
    }
    final recorded = await loadRecorded(mealId);
    final carbs = recorded?.netCarbsGrams;
    if (recorded == null || carbs == null || !carbs.isFinite || carbs <= 0) {
      throw StateError('Recorded carbohydrates required');
    }
    await repository.enqueue(
      mealId: mealId,
      identifier: createUuid(),
      sourceKey: nightscoutDeliveryKey(settings.url, settings.revision),
      eatenAt: recorded.eatenAt,
      carbs: carbs,
    );
  }
}
