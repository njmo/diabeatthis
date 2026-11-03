import '../../../core/data_sources/nightscout/helpers/nightscout_delivery_key.dart';
import 'nightscout_low_treatment_settings.dart';

enum LowTreatmentUploadDisplayStatus {
  queued,
  verifying,
  sent,
  cancelled,
  paused,
}

class ResolveLowTreatmentUploadStatusUseCase {
  const ResolveLowTreatmentUploadStatusUseCase();

  LowTreatmentUploadDisplayStatus call({
    required String state,
    required String sourceKey,
    NightscoutLowTreatmentSettings? settings,
  }) {
    if ((state == 'queued' || state == 'verifying') && settings != null) {
      if (!settings.enabled || settings.url.isEmpty) {
        return LowTreatmentUploadDisplayStatus.paused;
      }
      try {
        if (nightscoutDeliveryKey(settings.url, settings.revision) !=
            sourceKey) {
          return LowTreatmentUploadDisplayStatus.paused;
        }
      } on ArgumentError {
        return LowTreatmentUploadDisplayStatus.paused;
      }
    }
    return switch (state) {
      'sent' => LowTreatmentUploadDisplayStatus.sent,
      'cancelled' => LowTreatmentUploadDisplayStatus.cancelled,
      'paused' => LowTreatmentUploadDisplayStatus.paused,
      'verifying' => LowTreatmentUploadDisplayStatus.verifying,
      _ => LowTreatmentUploadDisplayStatus.queued,
    };
  }
}
