import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/publish_family_mirror_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response mirrorReceipt(Map data) => http.Response(
  jsonEncode({
    'result': {
      'sourceId': data['sourceId'],
      'acknowledged': (data['records'] as List)
          .map(
            (raw) => {
              'kind': raw['kind'],
              'id': raw['id'],
              'revision': raw['revision'],
            },
          )
          .toList(),
    },
  }),
  200,
);
void main() {
  for (final switchAt in [1, 2]) {
    test(
      'account changes before identity request $switchAt never transmit the previous account data',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        await db.customStatement(
          "INSERT INTO portion(name,unit_hint) VALUES('Spoon','unit')",
        );
        var uid = 'A';
        var identities = 0;
        var requests = 0;
        final transport = AuthenticatedCallableTransport(
          client: MockClient((request) async {
            requests++;
            final data = (jsonDecode(request.body) as Map)['data'] as Map;
            return http.Response(
              jsonEncode({
                'result': {'sourceId': data['sourceId']},
              }),
              200,
            );
          }),
          projectId: 'test',
          currentUid: () => uid,
          identity: () async {
            identities++;
            if (identities == switchAt) uid = 'B';
            return CallableIdentity(uid, 'token-$uid', 'app');
          },
        );
        await expectLater(
          PublishFamilyMirrorUseCase(
            outbox: FamilyMirrorOutbox(db),
            transport: transport,
            currentUid: () => uid,
          )(),
          throwsA(isA<CallableFailure>()),
        );
        expect(requests, switchAt - 1);
        expect((await FamilyMirrorOutbox(db).pending()).length, 1);
      },
    );
  }
  test(
    'disabling consent stops the next batch while preserving pending data',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      for (var i = 0; i < 26; i++) {
        await db.customStatement(
          'INSERT INTO portion(name,unit_hint) VALUES(?,?)',
          ['P$i', 'unit'],
        );
      }
      var consent = true;
      var uploads = 0;
      final started = Completer<void>();
      final reply = Completer<http.Response>();
      Map? pendingBody;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          if (request.url.path.endsWith('registerFamilyMirror'))
            return http.Response(
              jsonEncode({
                'result': {'sourceId': data['sourceId']},
              }),
              200,
            );
          uploads++;
          pendingBody = data;
          started.complete();
          return reply.future;
        }),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => const CallableIdentity('child', 'token', 'app'),
      );
      final action = PublishFamilyMirrorUseCase(
        outbox: FamilyMirrorOutbox(db),
        transport: transport,
        currentUid: () => 'child',
        canSend: () async => consent,
      )();
      await started.future;
      consent = false;
      reply.complete(mirrorReceipt(pendingBody!));
      await action;
      expect(uploads, 1);
      expect((await FamilyMirrorOutbox(db).pending()).length, 1);
    },
  );
  test(
    'batches respect byte limits and an oversized record cannot block valid rows',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      for (var i = 0; i < 15; i++) {
        await db.customStatement(
          'INSERT INTO meal(name,planned_at,notes) VALUES(?,?,?)',
          ['Meal$i', i, 'x' * (i == 0 ? 33000 : 20000)],
        );
      }
      var uploads = 0;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          if (request.url.path.endsWith('registerFamilyMirror'))
            return http.Response(
              jsonEncode({
                'result': {'sourceId': data['sourceId']},
              }),
              200,
            );
          uploads++;
          expect(utf8.encode(request.body).length, lessThanOrEqualTo(240000));
          return mirrorReceipt(data);
        }),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => const CallableIdentity('child', 'token', 'app'),
      );
      await PublishFamilyMirrorUseCase(
        outbox: FamilyMirrorOutbox(db),
        transport: transport,
        currentUid: () => 'child',
      )();
      expect(uploads, greaterThan(1));
      expect(await FamilyMirrorOutbox(db).pending(), isEmpty);
      final blocked = await db
          .customSelect(
            'SELECT * FROM family_sync_outbox WHERE failed_revision=revision',
          )
          .get();
      expect(blocked.length, 1);
      expect(blocked.single.read<int>('acknowledged_revision'), 0);
    },
  );
}
