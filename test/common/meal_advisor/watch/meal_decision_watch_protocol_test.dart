import 'dart:async';

import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_controller.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:diabeatthis/common/meal_advisor/watch/caregiver_watch_meals.dart';
import 'package:diabeatthis/common/meal_advisor/watch/meal_decision_watch_protocol.dart';
import 'package:diabeatthis/common/meal_advisor/watch/watch_meal_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '0123456789abcdef0123456789abcdef';
  const caregiver = 'caregiver';
  final deadline = DateTime.now()
      .add(const Duration(minutes: 5))
      .millisecondsSinceEpoch;
  final inbox = MealDecisionRemoteInbox(
    accountUid: caregiver,
    requests: [
      MealDecisionRemoteRequest({
        'id': id,
        'mealName': 'Lunch',
        'status': 'waiting',
        'deadline': deadline,
        'members': [
          {'uid': caregiver, 'status': 'available'},
        ],
      }),
    ],
  );

  test('opens an eligible request with transport-safe fields', () async {
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: caregiver, mode: MealDecisionWatchMode.caregiver),
      refreshInbox: () async => inbox,
    );
    expect(
      await protocol.exchange({
        'version': 1,
        'action': 'open',
        'requestId': id,
      }),
      {
        'version': 1,
        'status': 'ok',
        'mode': 'caregiver',
        'requests': [
          {'requestId': id, 'mealName': 'Lunch', 'deadlineMs': deadline},
        ],
      },
    );
  });

  test(
    'starts a watch add-on only for supported child portion choices',
    () async {
      var mode = MealDecisionWatchMode.child;
      final calls = <(int, double)>[];
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: 'account', mode: mode),
        refreshInbox: () async => throw StateError('Unexpected refresh'),
        startChildMealAddOn: (_, id, portions) async {
          calls.add((id, portions));
          return 'ok';
        },
      );
      Future<Object?> start(Object portions) async => (await protocol.exchange({
        'version': 1,
        'action': 'startMealAddOn',
        'mealId': 7,
        'totalPortions': portions,
      }))['status'];
      expect(await start(1.5), 'ok');
      expect(await start(2), 'ok');
      expect(await start(3), 'invalidRequest');
      expect(await start('1.5'), 'invalidRequest');
      mode = MealDecisionWatchMode.caregiver;
      expect(await start(1.5), 'unavailable');
      expect(calls, [(7, 1.5), (7, 2.0)]);
    },
  );

  test('detects child mode without fetching family data', () async {
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: 'child', mode: MealDecisionWatchMode.child),
      refreshInbox: () async => throw StateError('Unexpected refresh'),
    );
    expect(await protocol.exchange({'version': 1, 'action': 'mode'}), {
      'version': 1,
      'status': 'ok',
      'mode': 'child',
    });
  });

  test('caregiver sees the active meal or sorted plans', () {
    Map<String, dynamic> meal(int id, String status, int time) => {
      'payload': {
        'id': id,
        'name': 'Meal $id',
        'status': status,
        'planned_at': time,
      },
    };
    final day = DateTime.fromMillisecondsSinceEpoch(200);
    final plans = [meal(1, 'planned', 200), meal(2, 'planned', 100)];
    expect(caregiverWatchMeals(plans, day: day).map((meal) => meal.id), [2, 1]);
    expect(
      caregiverWatchMeals([
        ...plans,
        meal(3, 'eating', 300),
      ], day: day).map((meal) => meal.id),
      [3],
    );
    expect(
      caregiverWatchMeals([
        ...plans,
        meal(3, 'eaten', 300),
        meal(4, 'planned', -86400000),
        {
          'payload': {'id': 5, 'name': 'Undated', 'status': 'planned'},
        },
      ], day: day).map((meal) => meal.id),
      [2, 1],
    );
  });

  test(
    'watch meal progress uses the saved decision and real wait deadline',
    () {
      final startedAt = DateTime.utc(2026, 11, 21, 20, 10);
      expect(
        watchMealProgress(
          'bolused-waiting',
          waitStartedAt: startedAt,
          waitMinutes: 15,
        ),
        {
          'stage': 'waiting',
          'index': 1,
          'count': 3,
          'completed': [0],
          'waitUntilMs': DateTime.utc(
            2026,
            11,
            21,
            20,
            25,
          ).millisecondsSinceEpoch,
        },
      );
      final afterEating = watchMealProgress(
        'waiting-for-bolus',
        decision: MealDecision.eatNowBolusLater,
      );
      expect(afterEating['stage'], 'bolus');
      expect(afterEating['index'], 1);
      expect(afterEating['count'], 2);
      expect(afterEating.containsKey('carbs'), isFalse);
      expect(
        watchMealProgress('bolused-waiting').containsKey('waitUntilMs'),
        isFalse,
      );
    },
  );

  test('a pending first bolus does not add an extra meal step', () {
    final pending = MealAddOnBolusContext(
      originalStatus: 'eating-then-bolus',
      eatingStartedAt: DateTime.utc(2026, 11, 21, 20),
      requestedAt: DateTime.utc(2026, 11, 21, 20, 10),
      coveredCarbs: 0,
      statusCoveredCarbs: 0,
      reportedExtendedCarbs: 0,
      requestedCarbs: 20,
      requestedExtendedCarbs: 0,
      awaitingBolus: true,
      bolusConfirmed: false,
    );
    final original = watchMealProgress(
      'waiting-for-bolus',
      decision: MealDecision.eatNowBolusLater,
      history: ['eating-then-bolus', 'waiting-for-bolus'],
      addOn: pending,
    );
    expect(original['count'], 2);
    expect(original['index'], 1);
    expect(original['completed'], [0]);
    final withExtra = watchMealProgress(
      'waiting-for-bolus',
      history: ['eating-then-bolus', 'eating-extra', 'waiting-for-bolus'],
      addOn: pending,
    );
    expect(withExtra['count'], 3);
    expect(withExtra['index'], 2);
  });

  test(
    'watch lists match requests to meals and expose the claimed stage',
    () async {
      var mode = MealDecisionWatchMode.caregiver;
      var uid = caregiver;
      final claimUntil = DateTime.now()
          .add(const Duration(seconds: 30))
          .millisecondsSinceEpoch;
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: uid, mode: mode),
        refreshInbox: () async => MealDecisionRemoteInbox(
          accountUid: uid,
          requests: [
            MealDecisionRemoteRequest({
              ...inbox.requests.single.data,
              'mealId': '42',
              'ownerUid': 'child',
              'claimedByUid': caregiver,
              'claimedByName': 'Alex',
              'claimUntil': claimUntil,
              'stage': 'decision',
            }),
          ],
        ),
        loadCaregiverMeals: (_) => const [],
      );
      final list = {'version': 1, 'action': 'list'};
      final caregiverResult = await protocol.exchange(list);
      expect((caregiverResult['requests'] as List).single['mealId'], 42);
      uid = 'child';
      mode = MealDecisionWatchMode.child;
      final childResult = await protocol.exchange(list);
      expect((childResult['requests'] as List).single['stage'], 'decision');
    },
  );

  test('caregiver overview is independent of the remote inbox', () async {
    const plans = [
      {'mealId': 1, 'mealName': 'Lunch'},
    ];
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: caregiver, mode: MealDecisionWatchMode.caregiver),
      readInbox: () => const MealDecisionRemoteInbox(),
      refreshInbox: () async => throw StateError('Unexpected refresh'),
      loadCaregiverMeals: (_) => plans,
    );
    final response = await protocol.exchange({'version': 1, 'action': 'list'});
    expect(response['status'], 'ok');
    expect(response['plans'], plans);
    expect(response['inboxAvailable'], false);
  });

  test('child plans are available while the remote inbox is loading', () async {
    const plans = [
      {'mealId': 42, 'mealName': 'Owsianka', 'canRequest': true},
    ];
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: 'child', mode: MealDecisionWatchMode.child),
      readInbox: () => const MealDecisionRemoteInbox(),
      refreshInbox: () async => throw StateError('Unexpected refresh'),
      loadChildPlans: (_) async => plans,
      languageTag: () => 'pl',
    );
    expect(await protocol.exchange({'version': 1, 'action': 'list'}), {
      'version': 1,
      'status': 'ok',
      'mode': 'child',
      'requests': [],
      'plans': plans,
      'inboxAvailable': false,
      'languageTag': 'pl',
    });
  });

  test('requests a decision only for a valid child meal', () async {
    var mode = MealDecisionWatchMode.child;
    var sent = 0;
    final created = {'requestId': id, 'mealId': 42, 'deadlineMs': deadline};
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: 'child', mode: mode),
      refreshInbox: () async => throw StateError('Unexpected refresh'),
      requestChildDecision: (session, mealId, requestId) async {
        expect(session.uid, 'child');
        expect(mealId, 42);
        expect(requestId, id);
        sent++;
        return created;
      },
    );
    final command = {
      'version': 1,
      'action': 'requestDecision',
      'mealId': 42,
      'requestId': id,
    };
    expect((await protocol.exchange(command))['requests'], [created]);
    expect(
      (await protocol.exchange({...command, 'mealId': 0}))['status'],
      'invalidRequest',
    );
    mode = MealDecisionWatchMode.caregiver;
    expect((await protocol.exchange(command))['status'], 'unavailable');
    expect(sent, 1);
  });

  test('child meal commands act only on the selected meal', () async {
    var mode = MealDecisionWatchMode.child;
    final calls = <String>[];
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: 'child', mode: mode),
      refreshInbox: () async => throw StateError('Unexpected inbox request'),
      completeChildMeal: (_, mealId) async {
        calls.add('complete/$mealId');
        return 'phoneRequired';
      },
      openPhoneMealSummary: (_, mealId) async {
        calls.add('phone/$mealId');
        return 'ok';
      },
      startAcceptedMeal: (_, mealId) async {
        calls.add('start-accepted/$mealId');
        return 'ok';
      },
      startMealOnPhone: (_, mealId) async {
        calls.add('start/$mealId');
        return 'ok';
      },
      skipChildMeal: (_, mealId) async {
        calls.add('skip/$mealId');
        return 'ok';
      },
    );
    Future<Object?> command(String action, Object id) async => (await protocol
        .exchange({'version': 1, 'action': action, 'mealId': id}))['status'];
    expect(await command('completeMeal', 42), 'phoneRequired');
    expect(await command('phoneMealSummary', 42), 'ok');
    expect(await command('completeMeal', '42'), 'invalidRequest');
    expect(await command('startMealOnPhone', 43), 'ok');
    expect(await command('startAcceptedMeal', 43), 'ok');
    expect(await command('startAcceptedMeal', 0), 'invalidRequest');
    expect(await command('skipMeal', 44), 'ok');
    expect(await command('skipMeal', 0), 'invalidRequest');
    mode = MealDecisionWatchMode.caregiver;
    expect(await command('skipMeal', 44), 'unavailable');
    expect(await command('startMealOnPhone', 43), 'unavailable');
    expect(await command('completeMeal', 42), 'unavailable');
    expect(await command('startAcceptedMeal', 43), 'unavailable');
    expect(calls, [
      'complete/42',
      'phone/42',
      'start/43',
      'start-accepted/43',
      'skip/44',
    ]);
  });

  test(
    'presence keeps the active caregiver claim and returns its new end',
    () async {
      final lease = DateTime.now().add(const Duration(seconds: 30));
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: caregiver, mode: MealDecisionWatchMode.caregiver),
        refreshInbox: () async => MealDecisionRemoteInbox(
          accountUid: caregiver,
          requests: [
            MealDecisionRemoteRequest({
              ...inbox.requests.single.data,
              'claimedByUid': caregiver,
              'claimUntil': lease.millisecondsSinceEpoch,
            }),
          ],
        ),
        renewPresence: (_, requestId, stage) async {
          expect(requestId, id);
          expect(stage, 'decision');
          return lease.add(const Duration(seconds: 15)).millisecondsSinceEpoch;
        },
      );
      expect(
        await protocol.exchange({
          'version': 1,
          'action': 'presence',
          'requestId': id,
          'stage': 'decision',
        }),
        {
          'version': 1,
          'status': 'ok',
          'claimUntilMs': lease
              .add(const Duration(seconds: 15))
              .millisecondsSinceEpoch,
        },
      );
    },
  );

  test('lists the phone’s active requests without another fetch', () async {
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: caregiver, mode: MealDecisionWatchMode.caregiver),
      readInbox: () => inbox,
      refreshInbox: () async => throw StateError('Unexpected refresh'),
    );
    final result = await protocol.exchange({'version': 1, 'action': 'list'});
    expect(result['mode'], 'caregiver');
    expect(result['requests'], hasLength(1));
  });

  test('an active claim on the phone is removed from the watch list', () async {
    var watchOwnsClaim = false;
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: caregiver, mode: MealDecisionWatchMode.caregiver),
      refreshInbox: () async => MealDecisionRemoteInbox(
        accountUid: caregiver,
        requests: [
          MealDecisionRemoteRequest({
            ...inbox.requests.single.data,
            'claimedByUid': caregiver,
            'claimUntil': deadline,
          }),
        ],
      ),
      ownsClaim: (_, _) => watchOwnsClaim,
    );
    const list = {'version': 1, 'action': 'list'};
    expect((await protocol.exchange(list))['requests'], isEmpty);
    watchOwnsClaim = true;
    expect((await protocol.exchange(list))['requests'], hasLength(1));
  });

  test(
    'respond validates decisions and sends only for an active owner',
    () async {
      var owned = false;
      final submitted = <Map<String, Object?>>[];
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: caregiver, mode: MealDecisionWatchMode.caregiver),
        refreshInbox: () async => MealDecisionRemoteInbox(
          accountUid: caregiver,
          requests: [
            MealDecisionRemoteRequest({
              ...inbox.requests.single.data,
              if (owned) 'claimedByUid': caregiver,
              if (owned) 'claimUntil': deadline,
            }),
          ],
        ),
        respond: (_, requestId, decision) async {
          expect(requestId, id);
          submitted.add(decision);
          return true;
        },
      );
      final message = {
        'version': 1,
        'action': 'respond',
        'requestId': id,
        'type': 'deferMeal',
        'message': ' Later ',
        'minutes': 10,
      };
      expect((await protocol.exchange(message))['status'], 'unavailable');
      owned = true;
      expect(
        (await protocol.exchange({...message, 'minutes': 181}))['status'],
        'invalidRequest',
      );
      expect((await protocol.exchange(message))['status'], 'ok');
      expect(submitted, [
        {
          'type': 'deferMeal',
          'minutes': 10,
          'message': 'Later',
          'targetSuggestion': null,
        },
      ]);
    },
  );

  test('claim returns the confirmed caregiver lease', () async {
    final claimUntil = DateTime.now()
        .add(const Duration(seconds: 30))
        .millisecondsSinceEpoch;
    var claimed = false;
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: caregiver, mode: MealDecisionWatchMode.caregiver),
      refreshInbox: () async => claimed
          ? MealDecisionRemoteInbox(
              accountUid: caregiver,
              requests: [
                MealDecisionRemoteRequest({
                  ...inbox.requests.single.data,
                  'claimedByUid': caregiver,
                  'claimUntil': claimUntil,
                }),
              ],
            )
          : inbox,
      claim: (session, requestId) async {
        expect(session.uid, caregiver);
        expect(requestId, id);
        claimed = true;
        return true;
      },
    );
    final reply = await protocol.exchange({
      'version': 1,
      'action': 'claim',
      'requestId': id,
    });
    expect(reply['status'], 'ok');
    expect(reply['requests'], [
      {
        'requestId': id,
        'mealName': 'Lunch',
        'deadlineMs': deadline,
        'claimUntilMs': claimUntil,
      },
    ]);
  });

  test(
    'opening an answer notification refreshes a still-waiting cache',
    () async {
      var refreshes = 0;
      MealDecisionRemoteInbox response(String status) =>
          MealDecisionRemoteInbox(
            accountUid: 'child',
            requests: [
              MealDecisionRemoteRequest({
                ...inbox.requests.single.data,
                'ownerUid': 'child',
                'mealId': 42,
                'status': status,
                'response': {'type': 'eatThenInsulin'},
              }),
            ],
          );
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: 'child', mode: MealDecisionWatchMode.child),
        readInbox: () => response('waiting'),
        refreshInbox: () async {
          refreshes++;
          return response('answered');
        },
      );
      final result = await protocol.exchange({
        'version': 1,
        'action': 'list',
        'requestId': id,
        'openAnswer': true,
      });
      expect(refreshes, 1);
      expect((result['requests'] as List).single['status'], 'answered');
    },
  );

  test(
    'child sees and accepts only an answered decision for their meal',
    () async {
      var status = 'answered';
      var owner = 'child';
      var calls = 0;
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: 'child', mode: MealDecisionWatchMode.child),
        refreshInbox: () async => MealDecisionRemoteInbox(
          accountUid: 'child',
          requests: [
            MealDecisionRemoteRequest({
              ...inbox.requests.single.data,
              'ownerUid': owner,
              'mealId': 42,
              'status': status,
              'response': {
                'caregiverName': 'Alex',
                'decision': {
                  'type': 'deferMeal',
                  'minutes': 15,
                  'message': 'Later',
                },
              },
            }),
          ],
        ),
        acceptChildDecision: (_, request) async {
          calls++;
          expect(request.id, id);
          return true;
        },
      );
      final listed = await protocol.exchange({'version': 1, 'action': 'list'});
      expect((listed['requests'] as List).single['decision'], {
        'type': 'deferMeal',
        'minutes': 15,
        'note': 'Later',
        'caregiverName': 'Alex',
      });
      final accept = {
        'version': 1,
        'action': 'acceptDecision',
        'mealId': 42,
        'requestId': id,
      };
      expect(
        (await protocol.exchange({...accept, 'mealId': 43}))['status'],
        'unavailable',
      );
      status = 'waiting';
      expect((await protocol.exchange(accept))['status'], 'unavailable');
      status = 'answered';
      owner = 'another-child';
      expect((await protocol.exchange(accept))['status'], 'unavailable');
      owner = 'child';
      expect((await protocol.exchange(accept))['status'], 'ok');
      expect(calls, 1);
    },
  );

  test(
    'child watch distinguishes a declined request from expiration',
    () async {
      var reason = 'allCaregiversDeclined';
      var owner = 'child';
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: 'child', mode: MealDecisionWatchMode.child),
        refreshInbox: () async => MealDecisionRemoteInbox(
          accountUid: 'child',
          requests: [
            MealDecisionRemoteRequest({
              ...inbox.requests.single.data,
              'ownerUid': owner,
              'mealId': 42,
              'status': 'expired',
              'terminalReason': reason,
            }),
          ],
        ),
      );
      final list = {'version': 1, 'action': 'list', 'requestId': id};
      final declined = await protocol.exchange(list);
      expect(declined['allCaregiversDeclined'], isTrue);
      expect(declined['requests'], isEmpty);
      reason = 'timeout';
      expect(
        await protocol.exchange(list),
        isNot(contains('allCaregiversDeclined')),
      );
      reason = 'allCaregiversDeclined';
      owner = 'other';
      expect(
        await protocol.exchange(list),
        isNot(contains('allCaregiversDeclined')),
      );
    },
  );

  test(
    'child meal details are loaded on demand for the selected meal',
    () async {
      var role = MealDecisionWatchMode.child;
      final requested = <int>[];
      final protocol = MealDecisionWatchProtocol(
        session: () => (uid: 'child', mode: role),
        refreshInbox: () async =>
            throw StateError('Unexpected network request'),
        loadChildMealDetails: (_, mealId) async {
          requested.add(mealId);
          return {
            'mealName': 'Podwieczorek',
            'ingredients': ['Chleb'],
          };
        },
      );
      final message = {
        'version': 1,
        'action': 'childMealDetails',
        'mealId': 42,
      };
      expect((await protocol.exchange(message))['preview'], {
        'mealName': 'Podwieczorek',
        'ingredients': ['Chleb'],
      });
      role = MealDecisionWatchMode.caregiver;
      expect((await protocol.exchange(message))['status'], 'unavailable');
      expect(requested, [42]);
    },
  );

  test('watch notification can decline without loading the meal', () async {
    var mode = MealDecisionWatchMode.caregiver;
    final declined = <String>[];
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: caregiver, mode: mode),
      refreshInbox: () async => throw StateError('Unexpected inbox request'),
      decline: (_, requestId) async {
        declined.add(requestId);
        return true;
      },
    );
    final command = {'version': 1, 'action': 'decline', 'requestId': id};
    expect((await protocol.exchange(command))['status'], 'ok');
    mode = MealDecisionWatchMode.child;
    expect((await protocol.exchange(command))['status'], 'unavailable');
    expect(declined, [id]);
  });

  test('claim on phone dispatches directly to the caregiver handoff', () async {
    var mode = MealDecisionWatchMode.caregiver;
    final handoffs = <String>[];
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: caregiver, mode: mode),
      refreshInbox: () async => throw StateError('Unexpected inbox request'),
      claimOnPhone: (_, requestId) async {
        handoffs.add(requestId);
        return true;
      },
    );
    final command = {'version': 1, 'action': 'claimOnPhone', 'requestId': id};
    expect((await protocol.exchange(command))['status'], 'ok');
    expect(
      (await protocol.exchange({...command, 'requestId': 'bad'}))['status'],
      'invalidRequest',
    );
    mode = MealDecisionWatchMode.child;
    expect((await protocol.exchange(command))['status'], 'unavailable');
    expect(handoffs, [id]);
  });

  test('child list returns only the signed-in child’s requests', () async {
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: 'child', mode: MealDecisionWatchMode.child),
      refreshInbox: () async => MealDecisionRemoteInbox(
        accountUid: 'child',
        requests: [
          MealDecisionRemoteRequest({
            ...inbox.requests.single.data,
            'ownerUid': 'child',
            'mealId': '42',
          }),
          MealDecisionRemoteRequest({
            ...inbox.requests.single.data,
            'ownerUid': 'other-child',
          }),
        ],
      ),
    );
    expect(await protocol.exchange({'version': 1, 'action': 'list'}), {
      'version': 1,
      'status': 'ok',
      'mode': 'child',
      'inboxAvailable': true,
      'requests': [
        {
          'requestId': id,
          'mealName': 'Lunch',
          'deadlineMs': deadline,
          'status': 'waiting',
          'mealId': 42,
        },
      ],
    });
  });

  test('discards data when the caregiver changes during refresh', () async {
    final refresh = Completer<MealDecisionRemoteInbox>();
    var uid = caregiver;
    final protocol = MealDecisionWatchProtocol(
      session: () => (uid: uid, mode: MealDecisionWatchMode.caregiver),
      refreshInbox: () => refresh.future,
    );
    final reply = protocol.exchange({'version': 1, 'action': 'list'});
    uid = 'other';
    refresh.complete(inbox);

    expect(await reply, {'version': 1, 'status': 'unavailable'});
  });
}
