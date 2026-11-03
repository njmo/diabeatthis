import 'package:diabeatthis/core/data_sources/nightscout/helpers/nightscout_delivery_key.dart';
import 'package:diabeatthis/features/low_treatment/application/nightscout_low_treatment_settings.dart';
import 'package:diabeatthis/features/low_treatment/application/resolve_low_treatment_upload_status_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolve = ResolveLowTreatmentUploadStatusUseCase();
  final key = nightscoutDeliveryKey('https://example.test', 'original');
  test(
    'pending status pauses on disabled settings, changed server or invalid URL',
    () {
      for (final settings in [
        const NightscoutLowTreatmentSettings(),
        const NightscoutLowTreatmentSettings(
          enabled: true,
          url: 'https://example.test',
          revision: 'changed',
        ),
        const NightscoutLowTreatmentSettings(enabled: true, url: 'invalid'),
      ]) {
        expect(
          resolve(state: 'queued', sourceKey: key, settings: settings),
          LowTreatmentUploadDisplayStatus.paused,
        );
      }
    },
  );
  test('completed status remains completed when uploads are disabled', () {
    expect(
      resolve(
        state: 'sent',
        sourceKey: key,
        settings: const NightscoutLowTreatmentSettings(),
      ),
      LowTreatmentUploadDisplayStatus.sent,
    );
  });
}
