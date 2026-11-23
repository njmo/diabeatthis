import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/child_ingredient_search_repository.dart';
import 'package:diabeatthis/common/family_sync/edit_family_quick_treatment_use_case.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/family_sync/submit_family_plan_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'meal history remains available before the new server endpoint is deployed',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final calls = <String>[];
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final operation = request.url.pathSegments.last;
          calls.add(operation);
          return switch (operation) {
            'fetchFamilyMealHeaders' => http.Response('Not Found', 404),
            'fetchFamilyMirror' => http.Response(
              '{"result":{"ownerUid":"child","sourceId":"legacy","cursor":1,'
              '"hasMore":false,"records":[{"kind":"meals","id":"1","sequence":1}]}}',
              200,
            ),
            'fetchFamilyPlans' => http.Response(
              '{"result":{"ownerUid":"child","sourceId":"legacy","plans":[]}}',
              200,
            ),
            _ => throw StateError('Unexpected operation: $operation'),
          };
        }),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final history = FamilyPlanningController(
        transport,
        () => 'parent',
        FamilyPlanSubmissionStore(db),
        mealHistory: true,
      );
      addTearDown(history.dispose);
      await history.refreshAndWait();

      expect(history.failed, isFalse);
      expect(history.pagedMealHistory, isFalse);
      expect(history.rows.keys, ['meals/1']);
      expect(calls, [
        'fetchFamilyMealHeaders',
        'fetchFamilyMirror',
        'fetchFamilyPlans',
      ]);
    },
  );

  test('a prefetched page cannot cross a child mirror source change', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final oldPage = Completer<http.Response>();
    var source = 'old';
    http.Response reply(String source, {String? cursor, int meal = 1}) =>
        http.Response(
          jsonEncode({
            'result': {
              'ownerUid': 'child',
              'sourceId': source,
              'sequence': 1,
              'mealHeadersRevision': 1,
              'initialHeadersComplete': true,
              'nextCursor': cursor,
              'records': [
                {'kind': 'meals', 'id': '$meal'},
              ],
              'plans': [],
            },
          }),
          200,
        );
    final transport = AuthenticatedCallableTransport(
      client: MockClient((request) async {
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        if (data['cursor'] == 'old-next') return oldPage.future;
        return source == 'old'
            ? reply(source, cursor: 'old-next')
            : reply(source, meal: 3);
      }),
      projectId: 'test',
      currentUid: () => 'parent',
      identity: () async => const CallableIdentity('parent', 'token', 'app'),
    );
    final history = FamilyPlanningController(
      transport,
      () => 'parent',
      FamilyPlanSubmissionStore(db),
      mealHistory: true,
    );
    addTearDown(history.dispose);
    await history.refreshAndWait();
    final append = history.loadMoreMealHeaders();
    source = 'new';
    await history.refreshMirrorForSignal({
      'ownerUid': 'child',
      'sourceId': source,
      'sequence': 1,
    });
    oldPage.complete(reply('old', meal: 2));
    await append;
    expect(history.source, 'new');
    expect(history.rows.keys, ['meals/3']);
  });

  test(
    'meal history follows migration, prefetches one page and never loads full mirror',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final operations = <String>[];
      final calls = <Object?>[];
      var migrationPages = 0;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final operation = request.url.pathSegments.last;
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          operations.add(operation);
          final plans = operation == 'fetchFamilyPlans';
          final after = data['cursor'];
          if (!plans) calls.add(after);
          final migrating = !plans && migrationPages++ < 2;
          final id = after == 'next' ? '2' : '1';
          return http.Response(
            jsonEncode({
              'result': {
                'ownerUid': 'child',
                'sourceId': 'source',
                if (plans)
                  'plans': []
                else ...{
                  'sequence': 7,
                  'mealHeadersRevision': 3,
                  'initialHeadersComplete': !migrating,
                  'nextCursor': migrating
                      ? 'migration'
                      : after == 'next'
                      ? null
                      : 'next',
                  'records': [
                    if (!migrating)
                      {
                        'kind': 'meals',
                        'id': id,
                        'payload': {'id': int.parse(id)},
                      },
                  ],
                },
              },
            }),
            200,
          );
        }),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final history = FamilyPlanningController(
        transport,
        () => 'parent',
        FamilyPlanSubmissionStore(db),
        mealHistory: true,
        view: () => {'view': 'history'},
      );
      addTearDown(history.dispose);
      await history.refreshAndWait();
      expect(history.rows.keys, ['meals/1']);
      expect(history.historyReady, isTrue);
      expect(history.historyHasMore, isTrue);
      expect(
        history.hasMirrorSequence({
          'ownerUid': 'child',
          'sourceId': 'source',
          'sequence': 14,
          'mealHeadersRevision': 3,
        }),
        isTrue,
      );
      await history.loadMoreMealHeaders();
      expect(history.rows.keys, ['meals/1', 'meals/2']);
      expect(history.historyHasMore, isFalse);
      expect(calls, [null, 'migration', 'migration', 'next']);
      expect(
        operations,
        everyElement(anyOf('fetchFamilyMealHeaders', 'fetchFamilyPlans')),
      );
    },
  );

  test(
    'a pending submission clears after its planning session is disposed',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      var disposed = false;
      final store = FamilyPlanSubmissionStore.lazy(() {
        if (disposed) throw StateError('Planning session disposed');
        return db;
      });
      final reserved = await store.reserve('parent', {'id': 'plan'});
      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      final transport = AuthenticatedCallableTransport(
        client: MockClient((_) {
          requestStarted.complete();
          return response.future;
        }),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final submission = SubmitFamilyPlanUseCase(
        transport,
        store,
        (_) => !disposed,
      ).sendReserved('parent', reserved);
      await requestStarted.future;
      disposed = true;
      response.complete(
        http.Response('{"result":{"id":"plan","status":"pending"}}', 200),
      );
      await submission;
      expect(await store.pending('parent'), isNull);
    },
  );

  test(
    'scoped controllers keep home plans and meal details separate',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      const source = 'source';
      final operations = <String>[];
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          final operation = request.url.pathSegments.last;
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          operations.add('$operation/${data['view'] ?? ''}');
          final meal = data['view'] == 'meal';
          return http.Response(
            jsonEncode({
              'result': {
                'ownerUid': 'child',
                'sourceId': source,
                if (operation == 'fetchFamilyPlans')
                  'plans': []
                else ...{
                  'sequence': meal ? 20 : 10,
                  'records': [
                    {'kind': 'meals', 'id': '1'},
                    if (meal) {'kind': 'mealIngredients', 'id': '2'},
                  ],
                },
              },
            }),
            200,
          );
        }),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final store = FamilyPlanSubmissionStore(db);
      final home = FamilyPlanningController(
        transport,
        () => 'parent',
        store,
        view: () => {'view': 'home'},
      );
      final details = FamilyPlanningController(
        transport,
        () => 'parent',
        store,
        view: () => {'view': 'meal', 'mealId': 1},
      );
      addTearDown(home.dispose);
      addTearDown(details.dispose);
      await home.refreshAndWait();
      expect(operations, ['fetchFamilyMirrorView/home', 'fetchFamilyPlans/']);
      await details.refreshAndWait(mirrorOnly: true);
      expect(operations.last, 'fetchFamilyMirrorView/meal');
      expect(home.rows.keys, ['meals/1']);
      expect(home.cursor, 10);
      expect(details.rows.keys, ['meals/1', 'mealIngredients/2']);
      expect(details.cursor, 20);
      expect(home.complete && details.complete, isTrue);
    },
  );

  test('missing scoped endpoint falls back to an incremental mirror', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final operations = <String>[];
    final transport = AuthenticatedCallableTransport(
      client: MockClient((request) async {
        final operation = request.url.pathSegments.last;
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        operations.add('$operation/${data['after'] ?? ''}');
        if (operation == 'fetchFamilyMirrorView') {
          return http.Response(
            '<html>Not Found</html>',
            404,
            headers: {'content-type': 'text/html'},
          );
        }
        return http.Response(
          jsonEncode({
            'result': {
              'ownerUid': 'child',
              'sourceId': 'source',
              if (operation == 'fetchFamilyPlans')
                'plans': []
              else ...{
                'cursor': 20,
                'hasMore': false,
                'records': [
                  {'kind': 'meals', 'id': '1'},
                ],
              },
            },
          }),
          200,
        );
      }),
      projectId: 'test',
      currentUid: () => 'parent',
      identity: () async => const CallableIdentity('parent', 'token', 'app'),
    );
    final controller = FamilyPlanningController(
      transport,
      () => 'parent',
      FamilyPlanSubmissionStore(db),
      view: () => {'view': 'home'},
    );
    addTearDown(controller.dispose);
    await controller.refreshAndWait();
    await controller.refreshAndWait(mirrorOnly: true);
    expect(controller.failed, isFalse);
    expect(controller.rows.keys, ['meals/1']);
    expect(operations, [
      'fetchFamilyMirrorView/',
      'fetchFamilyMirror/0',
      'fetchFamilyPlans/',
      'fetchFamilyMirror/20',
    ]);
  });

  test('meal previews join startup and fetch only mirror deltas', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final startup = Completer<void>();
    var source = 'a' * 32;
    final afterValues = <int>[];
    var planReads = 0;
    final transport = AuthenticatedCallableTransport(
      client: MockClient((request) async {
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        final isMirror = request.url.path.endsWith('fetchFamilyMirror');
        final after = isMirror ? data['after'] as int : null;
        if (after != null) {
          afterValues.add(after);
          if (afterValues.length == 1) await startup.future;
        } else {
          planReads++;
        }
        return http.Response(
          jsonEncode({
            'result': {
              'ownerUid': 'child',
              'sourceId': source,
              if (after != null) ...{
                'records': [
                  {'kind': 'meals', 'id': source == 'a' * 32 ? '1' : '2'},
                ],
                'cursor': after + 1,
                'hasMore': false,
              } else
                'plans': [],
            },
          }),
          200,
        );
      }),
      projectId: 'test',
      currentUid: () => 'parent',
      identity: () async => const CallableIdentity('parent', 'token', 'app'),
    );
    final controller = FamilyPlanningController(
      transport,
      () => 'parent',
      FamilyPlanSubmissionStore(db),
    );
    addTearDown(controller.dispose);

    final full = controller.refreshAndWait();
    final watch = controller.refreshAndWait(mirrorOnly: true);
    expect(watch, same(full));
    startup.complete();
    await watch;
    expect(controller.complete, isTrue);
    expect(afterValues, [0]);
    expect(planReads, 1);

    await controller.refreshAndWait(mirrorOnly: true);
    expect(afterValues, [0, 1]);
    expect(planReads, 1);
    expect(controller.rows.keys, ['meals/1']);

    source = 'b' * 32;
    await controller.refreshAndWait(mirrorOnly: true);
    expect(afterValues, [0, 1, 2, 0]);
    expect(planReads, 2);
    expect(controller.rows.keys, ['meals/2']);
    expect(controller.complete, isTrue);
  });

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
