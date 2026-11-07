import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/publish_family_mirror_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
