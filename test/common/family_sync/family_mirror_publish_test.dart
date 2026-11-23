import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/publish_family_mirror_use_case.dart';
import 'package:diabeatthis/common/family_sync/register_family_mirror.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:diabeatthis/core/drift/family_sync/install_family_mirror_schema.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'mirror registration falls back to the installed server contract',
    () async {
      final calls = <Map<String, dynamic>>[];
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final data =
              (jsonDecode(request.body) as Map<String, dynamic>)['data']
                  as Map<String, dynamic>;
          calls.add(data);
          if (data.containsKey('mealHeadersExportVersion')) {
            return http.Response(
              '{"error":{"status":"INVALID_ARGUMENT"}}',
              400,
            );
          }
          return http.Response('{"result":{"sourceId":"legacy"}}', 200);
        }),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => const CallableIdentity('child', 'token', 'app'),
      );

      final response = await registerFamilyMirror(
        transport: transport,
        source: 'legacy',
        uid: 'child',
        permitted: () async => true,
      );

      expect(response, {'sourceId': 'legacy'});
      expect(calls, [
        {
          'sourceId': 'legacy',
          'activityCommandsVersion': 6,
          'mealHeadersExportVersion': 1,
        },
        {'sourceId': 'legacy', 'activityCommandsVersion': 6},
      ]);
    },
  );

  test(
    'an upgraded empty mirror retries header completion without republishing',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = FamilyMirrorOutbox(db);
      final source = await queue.bindOwner('child');
      await installFamilyMirrorSchema(db);
      expect(await queue.publishableMealHeaderCompletion, source);
      final calls = <String>[];
      var rejectCompletion = true;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final operation = request.url.pathSegments.last;
          calls.add(operation);
          if (operation == 'completeFamilyMealHeaderExport' &&
              rejectCompletion) {
            return http.Response('{"error":{"status":"UNAVAILABLE"}}', 503);
          }
          return http.Response(
            jsonEncode({
              'result': {
                'sourceId': source,
                if (operation == 'registerFamilyMirror')
                  'mealHeadersExportComplete': false,
              },
            }),
            200,
          );
        }),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => const CallableIdentity('child', 'token', 'app'),
      );
      final publish = PublishFamilyMirrorUseCase(
        outbox: queue,
        transport: transport,
        currentUid: () => 'child',
      );
      await expectLater(publish(), throwsA(isA<CallableFailure>()));
      expect(await queue.publishableMealHeaderCompletion, source);
      rejectCompletion = false;
      expect(await publish(), 0);
      await installFamilyMirrorSchema(db);
      expect(await queue.publishableMealHeaderCompletion, isNull);
      expect(await publish(), 0);
      expect(calls, [
        'registerFamilyMirror',
        'completeFamilyMealHeaderExport',
        'registerFamilyMirror',
        'completeFamilyMealHeaderExport',
      ]);
    },
  );

  test(
    'server failure does not mark data synced or bind the database to an unauthorized account',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO portion(name,unit_hint) VALUES('Spoon','unit')",
      );
      final queue = FamilyMirrorOutbox(db);
      final transport = AuthenticatedCallableTransport(
        client: MockClient(
          (_) async =>
              http.Response('{"error":{"status":"PERMISSION_DENIED"}}', 403),
        ),
        projectId: 'test',
        currentUid: () => 'wrong-user',
        identity: () async =>
            const CallableIdentity('wrong-user', 'token', 'app'),
      );
      await expectLater(
        PublishFamilyMirrorUseCase(
          outbox: queue,
          transport: transport,
          currentUid: () => 'wrong-user',
        )(),
        throwsA(isA<CallableFailure>()),
      );
      expect((await queue.pending()).length, 1);
      expect(
        (await db
                .customSelect('SELECT owner_uid FROM family_sync_identity')
                .getSingle())
            .readNullable<String>('owner_uid'),
        isNull,
      );
    },
  );
  test(
    'only exact receipts acknowledge data; bad receipts leave the queue pending',
    () async {
      for (final valid in [false, true]) {
        final db = DatabaseImpl(NativeDatabase.memory());
        try {
          await db.customStatement(
            "INSERT INTO portion(name,unit_hint) VALUES('Spoon','unit')",
          );
          final queue = FamilyMirrorOutbox(db);
          final transport = AuthenticatedCallableTransport(
            client: MockClient((request) async {
              final data = (jsonDecode(request.body) as Map)['data'] as Map;
              if (request.url.path.endsWith('registerFamilyMirror')) {
                return http.Response(
                  jsonEncode({
                    'result': {'sourceId': data['sourceId']},
                  }),
                  200,
                );
              }
              final records = data['records'] as List;
              return http.Response(
                jsonEncode({
                  'result': {
                    'sourceId': data['sourceId'],
                    'acknowledged': records
                        .map(
                          (record) => {
                            'kind': record['kind'],
                            'id': valid ? record['id'] : 'wrong',
                            'revision': record['revision'],
                          },
                        )
                        .toList(),
                  },
                }),
                200,
              );
            }),
            projectId: 'test',
            currentUid: () => 'child',
            identity: () async =>
                const CallableIdentity('child', 'token', 'app'),
          );
          final action = PublishFamilyMirrorUseCase(
            outbox: queue,
            transport: transport,
            currentUid: () => 'child',
          );
          if (valid) {
            await action();
            expect(await queue.pending(), isEmpty);
          } else {
            await expectLater(action(), throwsA(isA<CallableFailure>()));
            expect((await queue.pending()).length, 1);
          }
        } finally {
          await db.close();
        }
      }
    },
  );
}
