import '../../../core/data_sources/nightscout/helpers/nightscout_delivery_key.dart';
import '../../../core/data_sources/nightscout/treatments/nightscout_carbohydrate_writer.dart';
import '../../../core/data_sources/nightscout/treatments/nightscout_upload_needs_review.dart';
import '../data/repositories/low_treatment_upload_repository.dart';
import '../domain/models/recorded_low_treatment.dart';
import 'nightscout_low_treatment_settings.dart';

class ProcessLowTreatmentUploadsUseCase {
  const ProcessLowTreatmentUploadsUseCase({
    required this.repository,
    required this.writer,
    required this.loadSettings,
    required this.loadRecorded,
  });
  final LowTreatmentUploadRepository repository;
  final NightscoutCarbohydrateWriter writer;
  final Future<NightscoutLowTreatmentSettings> Function() loadSettings;
  final Future<RecordedLowTreatment?> Function(int) loadRecorded;

  Future<void> call(DateTime now) async {
    final settings = await loadSettings();
    if (!settings.enabled || settings.token.trim().isEmpty) return;
    final sourceKey = nightscoutDeliveryKey(settings.url, settings.revision);
    for (final upload in await repository.pending(now)) {
      if (upload.sourceKey != sourceKey) {
        await repository.update(upload.mealId, 'paused');
        continue;
      }
      if (upload.attempted == 0 &&
          await repository.hasMatchedTreatment(upload.mealId)) {
        // AAPS already supplied an unambiguous receipt: do not send a second intake.
        await repository.update(upload.mealId, 'sent');
        continue;
      }
      // Freeze the route and payload. Edits/deletion never trigger a second intake.
      final recorded = await loadRecorded(upload.mealId);
      final unchanged =
          recorded != null &&
          recorded.netCarbsGrams == upload.carbs &&
          recorded.eatenAt.millisecondsSinceEpoch == upload.eatenAt;
      if (!unchanged && upload.attempted == 0) {
        await repository.update(upload.mealId, 'cancelled');
        continue;
      }
      await repository.update(
        upload.mealId,
        'verifying',
        nextAttempt: now.add(const Duration(minutes: 2)),
      );
      try {
        final id = await writer.deliver(
          source: settings.url,
          token: settings.token,
          identifier: upload.identifier,
          eatenAt: DateTime.fromMillisecondsSinceEpoch(upload.eatenAt),
          carbs: upload.carbs,
          allowCreate:
              unchanged &&
              now.millisecondsSinceEpoch - upload.eatenAt <
                  const Duration(hours: 24).inMilliseconds,
          beforeCreate: () async {
            // Recheck the switch immediately before a remote write.
            final current = await loadSettings();
            if (!current.enabled ||
                nightscoutDeliveryKey(current.url, current.revision) !=
                    upload.sourceKey ||
                current.token != settings.token) {
              throw StateError('Upload settings changed');
            }
            await repository.update(
              upload.mealId,
              'verifying',
              attempted: true,
              nextAttempt: now.add(const Duration(minutes: 2)),
            );
          },
        );
        await repository.link(upload, id);
      } on NightscoutUploadNeedsReview {
        await repository.update(upload.mealId, 'paused');
      } catch (_) {
        // Keep the original identifier for recovery after a timeout or restart.
        await repository.update(
          upload.mealId,
          'verifying',
          nextAttempt: now.add(const Duration(minutes: 1)),
        );
      }
    }
  }
}
