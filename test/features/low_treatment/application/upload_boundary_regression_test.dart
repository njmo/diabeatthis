import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/application/nightscout_low_treatment_settings.dart';
import 'package:diabeatthis/features/low_treatment/application/process_low_treatment_uploads_use_case.dart';
import 'package:diabeatthis/features/low_treatment/application/register_low_treatment_upload_use_case.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/regression/scripted_carbohydrate_writer.dart';
import '../../../helpers/regression/scripted_low_treatment_upload_repository.dart';
import '../../../helpers/regression/scripted_read.dart';

void main() {
  final time = DateTime.utc(2026, 11, 1, 12);
  const settings = NightscoutLowTreatmentSettings(
    enabled: true,
    url: 'https://example.test/',
    token: 'test-token',
  );
  RecordedLowTreatment recorded(double carbs) => RecordedLowTreatment(
    mealId: 7,
    eatenAt: time,
    netCarbsGrams: carbs,
    suggestedCarbs: 30,
  );
  test(
    'registration freezes actual consumption and source identity instead of suggested carbs',
    () async {
      final repository = ScriptedLowTreatmentUploadRepository();
      final reads = ScriptedRead<RecordedLowTreatment?>('recorded intake', [
        (arguments: [7], respond: () => recorded(12.5)),
      ]);
      await RegisterLowTreatmentUploadUseCase(
        repository: repository,
        loadSettings: () async => settings,
        loadRecorded: (id) => reads([id]),
      )(7);
      expect(repository.queued, hasLength(1));
      final row = repository.queued.single;
      expect(row['mealId'], 7);
      expect(row['carbs'], 12.5);
      expect(
        row['sourceKey'],
        'cd9c37a15123d24130dc7cfd86dc2833b091a941e1e33142929bf2e4878362aa',
      );
      expect(row['eatenAt'], time);
      expect(
        row['identifier'],
        isA<String>().having((id) => id.isNotEmpty, 'non-empty', true),
      );
      reads.verifyComplete();
    },
  );
  test(
    'disabled uploads cannot read intake or enqueue a remote operation',
    () async {
      final repository = ScriptedLowTreatmentUploadRepository();
      final reads = ScriptedRead<RecordedLowTreatment?>('recorded intake', []);
      await RegisterLowTreatmentUploadUseCase(
        repository: repository,
        loadSettings: () async => const NightscoutLowTreatmentSettings(),
        loadRecorded: (id) => reads([id]),
      )(7);
      expect(repository.queued, isEmpty);
      reads.verifyComplete();
    },
  );
  for (final changed in [false, true]) {
    test(
      'processing keeps frozen payload and avoids creation after edits; changed=$changed',
      () async {
        final repository = ScriptedLowTreatmentUploadRepository()
          ..matched = ScriptedRead<bool>('existing receipt', [
            (arguments: [7], respond: () => false),
          ])
          ..pendingRows = [
            LowTreatmentUploadData(
              mealId: 7,
              identifier: 'stable-identifier',
              sourceKey:
                  'cd9c37a15123d24130dc7cfd86dc2833b091a941e1e33142929bf2e4878362aa',
              eatenAt: time.millisecondsSinceEpoch,
              carbs: 12.5,
              state: 'queued',
              attempted: 0,
              nextAttemptAt: 0,
            ),
          ];
        final reads = ScriptedRead<RecordedLowTreatment?>('recorded intake', [
          (arguments: [7], respond: () => recorded(changed ? 20 : 12.5)),
        ]);
        final deliveries = ScriptedRead<String>(
          'Nightscout delivery',
          changed
              ? []
              : [
                  (
                    arguments: [
                      'https://example.test/',
                      'test-token',
                      'stable-identifier',
                      time.millisecondsSinceEpoch,
                      12.5,
                      true,
                    ],
                    respond: () => 'stable-identifier',
                  ),
                ],
        );
        final now = time.add(const Duration(minutes: 5));
        await ProcessLowTreatmentUploadsUseCase(
          repository: repository,
          writer: ScriptedCarbohydrateWriter(deliveries),
          loadSettings: () async => settings,
          loadRecorded: (id) => reads([id]),
        )(now);
        expect(repository.pendingReads, [now]);
        repository.matched!.verifyComplete();
        if (changed) {
          expect(repository.updates.map((row) => row['state']), ['cancelled']);
          expect(repository.links, isEmpty);
        } else {
          expect(repository.updates.map((row) => row['state']), [
            'verifying',
            'verifying',
          ]);
          expect(repository.updates.last['attempted'], true);
          expect(repository.links, [(mealId: 7, externalId: 'stable-identifier')]);
        }
        reads.verifyComplete();
        deliveries.verifyComplete();
      },
    );
  }
  test(
    'disabling uploads immediately before a remote write prevents delivery',
    () async {
      final repository = ScriptedLowTreatmentUploadRepository()
        ..matched = ScriptedRead<bool>('existing receipt', [
          (arguments: [7], respond: () => false),
        ])
        ..pendingRows = [
          LowTreatmentUploadData(
            mealId: 7,
            identifier: 'stable-identifier',
            sourceKey:
                'cd9c37a15123d24130dc7cfd86dc2833b091a941e1e33142929bf2e4878362aa',
            eatenAt: time.millisecondsSinceEpoch,
            carbs: 12.5,
            state: 'queued',
            attempted: 0,
            nextAttemptAt: 0,
          ),
        ];
      final settingsReads =
          ScriptedRead<NightscoutLowTreatmentSettings>('upload settings', [
            (arguments: [], respond: () => settings),
            (
              arguments: [],
              respond: () => const NightscoutLowTreatmentSettings(),
            ),
          ]);
      final deliveries = ScriptedRead<String>('Nightscout delivery', []);
      await ProcessLowTreatmentUploadsUseCase(
        repository: repository,
        writer: ScriptedCarbohydrateWriter(deliveries),
        loadSettings: () => settingsReads([]),
        loadRecorded: (id) async {
          expect(id, 7);
          return recorded(12.5);
        },
      )(time);
      expect(repository.links, isEmpty);
      expect(
        repository.updates.last['nextAttempt'],
        time.add(const Duration(minutes: 1)),
      );
      repository.matched!.verifyComplete();
      settingsReads.verifyComplete();
      deliveries.verifyComplete();
    },
  );
}
