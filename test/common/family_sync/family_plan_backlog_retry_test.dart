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
    'unacknowledged journal requests a retry until a large mirror backlog drains',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final source = await FamilyMirrorOutbox(db).bindOwner('child');
      await db.customStatement('UPDATE family_sync_identity SET enabled=1');
      await db.transaction(() async {
        for (var i = 1; i <= 600; i++) {
          await db.customStatement(
            'INSERT INTO activity(name,percentage_pre,percentage_post) VALUES(?,20,30)',
            ['Walk $i'],
          );
        }
      });
      final revision =
          (await db
                  .customSelect(
                    "SELECT revision FROM family_sync_outbox WHERE kind='activities' AND entity_id='600'",
                  )
                  .getSingle())
              .read<int>('revision');
      await db.customStatement(
        'INSERT INTO family_plan_journal(operation_id,claim_token,owner_uid,source_id,outcome,result_id,required_revisions,result_bound) VALUES(?,?,?,?,?,?,?,1)',
        [
          'a' * 32,
          'b' * 32,
          'child',
          source,
          'applied',
          1,
          jsonEncode([
            {'kind': 'activities', 'id': '600', 'revision': revision},
          ]),
        ],
      );
      var acknowledgements = 0;
      var sequence = 0;
      final client = MockClient((request) async {
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        final result = switch (request.url.path.split('/').last) {
          'registerFamilyMirror' => {'sourceId': source},
          'fetchFamilyPlans' => {
            'ownerUid': 'child',
            'sourceId': source,
            'plans': [],
          },
          'publishFamilyMirror' => {
            'sourceId': source,
            'sequence': ++sequence,
            'acknowledged': [
              for (final row in data['records'] as List)
                {
                  'kind': row['kind'],
                  'id': row['id'],
                  'revision': row['revision'],
                },
            ],
          },
          'acknowledgeFamilyPlan' => {
            'id': data['id'],
            'status': data['outcome'],
          },
          _ => throw StateError('Unexpected call'),
        };
        if (request.url.path.endsWith('/acknowledgeFamilyPlan')) {
          acknowledgements++;
        }
        return http.Response(jsonEncode({'result': result}), 200);
      });
      addTearDown(client.close);
      final synchronize = SynchronizeFamilyPlansUseCase(
        db: db,
        transport: AuthenticatedCallableTransport(
          client: client,
          projectId: 'test',
          currentUid: () => 'child',
          identity: () async =>
              const CallableIdentity('child', 'token', 'appcheck'),
        ),
        currentUid: () => 'child',
      );
      expect(await synchronize(), isTrue);
      expect(acknowledgements, 0);
      expect(await synchronize(), isFalse);
      expect(acknowledgements, 1);
      expect(
        (await db
                .customSelect('SELECT acknowledged FROM family_plan_journal')
                .getSingle())
            .read<int>('acknowledged'),
        1,
      );
    },
  );
}
