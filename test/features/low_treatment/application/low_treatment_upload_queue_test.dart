import 'dart:convert';

import 'package:diabeatthis/core/data_sources/nightscout/helpers/nightscout_delivery_key.dart';
import 'package:diabeatthis/core/data_sources/nightscout/treatments/nightscout_carbohydrate_writer.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/application/nightscout_low_treatment_settings.dart';
import 'package:diabeatthis/features/low_treatment/application/process_low_treatment_uploads_use_case.dart';
import 'package:diabeatthis/features/low_treatment/application/register_low_treatment_upload_use_case.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_upload_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final at = DateTime.utc(2026, 11, 3, 12);
  const enabled = NightscoutLowTreatmentSettings(
    enabled: true,
    url: 'https://example.test',
    token: 'secret',
    revision: 'original',
  );
  late DatabaseImpl db;
  late LowTreatmentUploadRepository repository;
  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    repository = LowTreatmentUploadRepository(db);
  });
  tearDown(() async {
    await db.close();
  });

  Future<void> enqueue() => repository.enqueue(
    mealId: 7,
    identifier: 'stable-id',
    sourceKey: nightscoutDeliveryKey(enabled.url, enabled.revision),
    eatenAt: at,
    carbs: 12.5,
  );
  RecordedLowTreatment recorded() => RecordedLowTreatment(
    mealId: 7,
    eatenAt: at,
    netCarbsGrams: 12.5,
    suggestedCarbs: 30,
  );

  test(
    'registration is rolled back with the consumption transaction',
    () async {
      final register = RegisterLowTreatmentUploadUseCase(
        repository: repository,
        loadSettings: () async => enabled,
        loadRecorded: (_) async => recorded(),
      );
      await expectLater(
        db.transaction(() async {
          await register(7);
          throw StateError('rollback');
        }),
        throwsStateError,
      );
      expect(await repository.find(7), isNull);
      await register(7);
      final row = (await repository.find(7))!;
      expect(row.carbs, 12.5);
      expect(row.sourceKey, isNot(contains('example.test')));
      expect(row.identifier, isNotEmpty);
    },
  );

  test(
    'disabled option does not enqueue historical or existing records',
    () async {
      final register = RegisterLowTreatmentUploadUseCase(
        repository: repository,
        loadSettings: () async => const NightscoutLowTreatmentSettings(),
        loadRecorded: (_) async => throw StateError('must not load'),
      );
      await register(7);
      expect(await repository.find(7), isNull);
    },
  );

  test(
    'lost POST response is verified after worker restart without another POST',
    () async {
      await enqueue();
      Map<String, dynamic>? stored;
      var posts = 0;
      final client = MockClient((request) async {
        if (request.url.path.contains('/authorization/')) {
          return http.Response('{"token":"jwt"}', 200);
        }
        if (request.method == 'GET') {
          return stored == null
              ? http.Response('{}', 404)
              : http.Response(jsonEncode({'result': stored}), 200);
        }
        posts++;
        stored = jsonDecode(request.body) as Map<String, dynamic>;
        throw http.ClientException('response lost');
      });
      ProcessLowTreatmentUploadsUseCase worker() =>
          ProcessLowTreatmentUploadsUseCase(
            repository: repository,
            writer: NightscoutCarbohydrateWriter(client: client),
            loadSettings: () async => enabled,
            loadRecorded: (_) async => recorded(),
          );
      await worker()(at);
      expect((await repository.find(7))!.state, 'verifying');
      expect((await repository.find(7))!.attempted, 1);
      await worker()(at.add(const Duration(minutes: 2)));
      expect((await repository.find(7))!.state, 'sent');
      expect(posts, 1);
    },
  );

  test(
    'disabling pauses uploads; a URL change permanently stops old queue even after returning',
    () async {
      await enqueue();
      var settings = const NightscoutLowTreatmentSettings();
      var requests = 0;
      final worker = ProcessLowTreatmentUploadsUseCase(
        repository: repository,
        writer: NightscoutCarbohydrateWriter(
          client: MockClient((_) async {
            requests++;
            throw StateError('must not request');
          }),
        ),
        loadSettings: () async => settings,
        loadRecorded: (_) async => recorded(),
      );
      await worker(at);
      expect((await repository.find(7))!.state, 'queued');
      settings = const NightscoutLowTreatmentSettings(
        enabled: true,
        url: 'https://example.test',
        token: 'secret',
        revision: 'changed-and-returned',
      );
      await worker(at);
      expect((await repository.find(7))!.state, 'paused');
      settings = enabled;
      await worker(at.add(const Duration(minutes: 2)));
      expect((await repository.find(7))!.state, 'paused');
      expect(requests, 0);
    },
  );

  test('local deletion before the first attempt cancels delivery', () async {
    await enqueue();
    var requests = 0;
    await ProcessLowTreatmentUploadsUseCase(
      repository: repository,
      writer: NightscoutCarbohydrateWriter(
        client: MockClient((_) async {
          requests++;
          throw StateError('must not request');
        }),
      ),
      loadSettings: () async => enabled,
      loadRecorded: (_) async => null,
    )(at);
    expect((await repository.find(7))!.state, 'cancelled');
    expect(requests, 0);
  });
}
