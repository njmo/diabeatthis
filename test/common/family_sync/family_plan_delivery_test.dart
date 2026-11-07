import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/synchronize_family_plans_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'family_plan_apply_test.dart' show localPlan, seedPlanIngredient;

void main() {
  test(
    'lost cloud ACK retries journal without duplicating a child meal',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      final plan = await localPlan(db, 'createMeal');
      final source = plan['sourceId'];
      var acknowledged = false;
      var ackAttempts = 0;
      var claims = 0;
      var sequence = 0;
      final published = <String, Map>{};
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          Object result;
          switch (request.url.path.split('/').last) {
            case 'fetchFamilyPlans':
              result = {
                'ownerUid': 'child',
                'sourceId': source,
                'plans': acknowledged ? [] : [plan],
              };
            case 'claimFamilyPlan':
              claims++;
              result = plan;
            case 'registerFamilyMirror':
              result = {'sourceId': source};
            case 'publishFamilyMirror':
              for (final row in data['records'] as List) {
                published['${row['kind']}/${row['id']}'] = row as Map;
              }
              result = {
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
              };
            case 'acknowledgeFamilyPlan':
              if (data['outcome'] == 'prepared') {
                return http.Response(
                  jsonEncode({
                    'result': {'id': plan['id'], 'status': 'pending'},
                  }),
                  200,
                );
              }
              expect(published.keys, contains('meals/1'));
              expect(
                published.keys.any((key) => key.startsWith('mealIngredients/')),
                true,
              );
              ackAttempts++;
              if (ackAttempts == 1) {
                return http.Response('{"error":{"status":"UNAVAILABLE"}}', 503);
              }
              acknowledged = true;
              result = {'id': plan['id'], 'status': 'applied'};
            default:
              throw StateError('Unexpected endpoint');
          }
          return http.Response(jsonEncode({'result': result}), 200);
        }),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => const CallableIdentity('child', 'token', 'app'),
      );
      final synchronize = SynchronizeFamilyPlansUseCase(
        db: db,
        transport: transport,
        currentUid: () => 'child',
      );
      await expectLater(synchronize(), throwsA(isA<CallableFailure>()));
      expect(await db.select(db.meal).get(), hasLength(1));
      expect(
        (await db
                .customSelect('SELECT acknowledged FROM family_plan_journal')
                .getSingle())
            .read<int>('acknowledged'),
        0,
      );
      await synchronize();
      expect(claims, 1);
      expect(ackAttempts, 2);
      expect(await db.select(db.meal).get(), hasLength(1));
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
