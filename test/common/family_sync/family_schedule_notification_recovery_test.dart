import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/synchronize_family_plans_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'schedule notification cancellation survives partial failure before final ACK',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = FamilyMirrorOutbox(db);
      final source = await queue.bindOwner('child');
      await db.customStatement('UPDATE family_sync_identity SET enabled=1');
      await db.customStatement(
        "INSERT INTO family_plan_journal(operation_id,claim_token,owner_uid,source_id,outcome,result_id,required_revisions,result_bound) VALUES(?,?,'child',?,'applied',5,'[]',1)",
        ['a' * 32, 'b' * 32, source],
      );
      for (final id in [9, 10]) {
        await db.customStatement(
          'INSERT INTO family_plan_notification_cancellations(operation_id,occurrence_id) VALUES(?,?)',
          ['a' * 32, id],
        );
      }
      var acknowledgements = 0;
      final client = MockClient((request) async {
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        final name = request.url.path.split('/').last;
        Map result;
        if (name == 'acknowledgeFamilyPlan') {
          acknowledgements++;
          result = {'id': data['id'], 'status': 'applied'};
        } else if (name == 'registerFamilyMirror') {
          result = {'sourceId': source};
        } else {
          throw StateError(name);
        }
        return http.Response(jsonEncode({'result': result}), 200);
      });
      addTearDown(client.close);
      final transport = AuthenticatedCallableTransport(
        client: client,
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => const CallableIdentity('child', 'token', 'check'),
      );
      final canceled = <int>[];
      var fail = true;
      SynchronizeFamilyPlansUseCase runner() => SynchronizeFamilyPlansUseCase(
        db: db,
        transport: transport,
        currentUid: () => 'child',
        cancelConfirmation: (id) async {
          canceled.add(id);
          if (id == 10 && fail) {
            throw StateError('Temporary notification failure');
          }
        },
      );
      await expectLater(
        runner().drain('child', source, queue, () async => true),
        throwsStateError,
      );
      expect(acknowledgements, 0);
      fail = false;
      await runner().drain('child', source, queue, () async => true);
      expect(canceled, [9, 10, 10]);
      expect(acknowledgements, 1);
      expect(
        (await db
                .customSelect('SELECT acknowledged FROM family_plan_journal')
                .getSingle())
            .data['acknowledged'],
        1,
      );
    },
  );
}
