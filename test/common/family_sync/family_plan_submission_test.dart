import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/child_ingredient_search_repository.dart';
import 'package:diabeatthis/common/family_sync/edit_family_quick_treatment_use_case.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'quick treatment editor submits the selected child mirror versions',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final source = 'a' * 32;
      final rows = [
        {
          'kind': 'ingredients',
          'id': '1',
          'revision': 7,
          'payload': {'id': 1},
          'deleted': false,
        },
      ];
      var planSource = 'b' * 32;
      Map<String, dynamic>? submitted;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          final operation = request.url.pathSegments.last;
          final result = switch (operation) {
            'searchFamilyMirrorIngredients' => {
              'ownerUid': 'child',
              'sourceId': source,
              'records': rows,
            },
            'fetchFamilyPlans' => {
              'ownerUid': 'child',
              'sourceId': planSource,
              'plans': [],
            },
            'submitFamilyPlan' => {'id': data['id'], 'status': 'pending'},
            _ => throw StateError('Unexpected operation: $operation'),
          };
          if (operation == 'submitFamilyPlan') {
            submitted = Map<String, dynamic>.from(data);
          }
          return http.Response(jsonEncode({'result': result}), 200);
        }),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final store = FamilyPlanSubmissionStore(db);
      final editor = EditFamilyQuickTreatmentUseCase(
        ChildIngredientSearchRepository(
          transport: transport,
          caregiverUid: 'parent',
          childUid: 'child',
          isCurrent: () => true,
        ),
        store,
      );

      await expectLater(editor.load(), throwsStateError);
      planSource = source;
      final snapshot = await editor.load();
      expect(snapshot.rows, rows);
      expect(snapshot.pending, isFalse);
      expect(await editor.ingredientRows(1, source), rows);
      await editor.save(
        sourceId: snapshot.sourceId,
        rows: snapshot.rows,
        items: [
          {'ingredientId': 1, 'amount': 2},
        ],
      );

      expect(submitted?['type'], 'replaceQuickTreatmentItems');
      expect(submitted?['sourceId'], source);
      expect(submitted?['expected'], [
        {'kind': 'ingredients', 'id': '1', 'revision': 7},
      ]);
      expect(await store.pending('parent'), isNull);
    },
  );

  test(
    'ambiguous parent send is durable and reuses exact ID after reopening',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final source = 'a' * 32;
      final received = <Map>[];
      var attempts = 0;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          Object response;
          if (request.url.path.endsWith('submitFamilyPlan')) {
            received.add(data);
            if (++attempts == 1) {
              return http.Response('{"error":{"status":"UNAVAILABLE"}}', 503);
            }
            response = {'id': data['id'], 'status': 'pending'};
          } else if (request.url.path.endsWith('fetchFamilyMirror')) {
            response = {
              'ownerUid': 'child',
              'sourceId': source,
              'records': [],
              'cursor': 0,
              'hasMore': false,
            };
          } else {
            response = {'ownerUid': 'child', 'sourceId': source, 'plans': []};
          }
          return http.Response(jsonEncode({'result': response}), 200);
        }),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final store = FamilyPlanSubmissionStore(db);
      final first = FamilyPlanningController(transport, () => 'parent', store)
        ..uid = 'parent'
        ..source = source
        ..complete = true;
      await expectLater(
        first.submit(
          type: 'planActivity',
          targetId: null,
          values: {
            'activityId': 1,
            'startedAt': 9999999999999,
            'durationMinutes': 30,
          },
          baseRows: [
            {
              'kind': 'activities',
              'id': '1',
              'revision': 1,
              'payload': {'id': 1},
              'deleted': false,
            },
          ],
          expectedSource: source,
          expectedUid: 'parent',
        ),
        throwsA(isA<CallableFailure>()),
      );
      expect(await store.pending('parent'), isNotNull);
      expect(await store.pending('different-parent'), isNull);
      first.dispose();
      final reopened = FamilyPlanningController(
        transport,
        () => 'parent',
        store,
      );
      addTearDown(reopened.dispose);
      await reopened.refresh();
      expect(received, hasLength(2));
      expect(received[0], received[1]);
      expect(await store.pending('parent'), isNull);
    },
  );
}
