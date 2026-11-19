import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_background.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_consumption_action.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_presenter.dart';
import 'package:diabeatthis/core/notifications/mappers/android_notification_details_mapper.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements FamilyChatApi {
  bool offline = false;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      throw const CallableFailure('cancelled');
    }
    expect(operation, 'acknowledgeFamilyChatMessages');
    if (offline) throw const CallableFailure('unavailable');
    return {'ok': true};
  }
}

void main() {
  test('offline feedback has no stale clinical retry action', () async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final scope = jsonEncode(['child', 'family', 'e']);
    await db.activateChat('child', scope, 'stamp');
    final payload = {
      'type': 'familyChat',
      ...await db.activeChat(),
      'messageId': 'request',
    };
    await handleFamilyChatConsumption(
      db: db,
      api: _Api(),
      payload: payload,
      currentUid: () => 'child',
      confirm: (_, _) async => throw const CallableFailure('unavailable'),
      lookup: (_, _) async => (mealId: null, acknowledged: false),
      show: (notice, state) async {
        expect(state, FamilyConsumptionNotice.pending);
        final details = AndroidFamilyChatPresenter.consumptionEvent(
          notice,
          payload,
          FamilyConsumptionNotice.pending,
        ).toAndroidNotificationDetails();
        expect(details.actions, isEmpty);
        expect(details.timeoutAfter, 30000);
      },
      cancel: (_) async {},
    );
  });
  for (final state in FamilyConsumptionNotice.values) {
    test(
      'consumption feedback is durable, private and truthful: $state',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final scope = jsonEncode(['child', 'family', 'e']);
        await db.activateChat('child', scope, 'stamp');
        final guard = await db.activeChat();
        final payload = {
          'type': 'familyChat',
          ...guard,
          'messageId': 'request',
          'target': 'mom',
        };
        final api = _Api()..offline = state == FamilyConsumptionNotice.pending;
        var showed = 0;
        final result = switch (state) {
          FamilyConsumptionNotice.recorded => (mealId: 42, acknowledged: true),
          FamilyConsumptionNotice.recordedAwaitingAck => (
            mealId: 42,
            acknowledged: false,
          ),
          FamilyConsumptionNotice.completedElsewhere => (
            mealId: null,
            acknowledged: true,
          ),
          _ => (mealId: null, acknowledged: false),
        };
        expect(
          await handleFamilyChatConsumption(
            db: db,
            api: api,
            payload: payload,
            currentUid: () => 'child',
            confirm: (_, _) async {
              if (state == FamilyConsumptionNotice.pending) {
                throw const CallableFailure('unavailable');
              }
              if (state == FamilyConsumptionNotice.anotherDevice) {
                throw const CallableFailure(
                  'rejected',
                  rejectionCode: 'already-exists',
                );
              }
              if (state == FamilyConsumptionNotice.unavailable) {
                throw const CallableFailure('unauthenticated');
              }
              return result;
            },
            lookup: (_, _) async => result,
            show: (notice, actual) async {
              showed++;
              expect(actual, state);
              expect(await db.hasCancellationIntent(notice), true);
              final details = AndroidFamilyChatPresenter.consumptionEvent(
                notice,
                payload,
                actual,
              ).toAndroidNotificationDetails();
              expect(details.visibility, NotificationVisibility.private);
              expect(details.silent, true);
              expect(details.onlyAlertOnce, true);
              expect(details.actions?.isNotEmpty, false);
              expect(details.importance, Importance.defaultImportance);
              expect(details.priority, Priority.defaultPriority);
              expect(details.category, isNull);
              expect(details.styleInformation, isNull);
              expect(details.channelDescription, isNull);
            },
            cancel: (_) async {},
          ),
          true,
        );
        expect(showed, 1);
        expect(
          await db.notificationShown(
            scope,
            familyChatNotice(scope, 'request').id,
            tag: familyChatNotice(scope, 'request').tag,
          ),
          true,
        );
        expect(await db.locallyRead(scope, 'request'), true);
        expect(
          await db.receipts(scope),
          state == FamilyConsumptionNotice.pending ? hasLength(1) : isEmpty,
        );
      },
    );
  }
  for (final invalid in ['oldStamp', 'off', 'uid', 'lateUid', 'lateOff']) {
    test(
      'an old notification cannot cross consent or account generations: $invalid',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final scope = jsonEncode(['child', 'family', 'e']);
        await db.activateChat('child', scope, 'stamp');
        final payload = {
          'type': 'familyChat',
          ...await db.activeChat(),
          'messageId': 'request',
        };
        String? uid = 'child';
        if (invalid == 'oldStamp') {
          await db.deactivateChat();
          await db.activateChat('child', scope, 'new-stamp');
        }
        if (invalid == 'off') await db.deactivateChat();
        if (invalid == 'uid') uid = 'other';
        var confirms = 0, shows = 0;
        final handled = await handleFamilyChatConsumption(
          db: db,
          api: _Api(),
          payload: payload,
          currentUid: () => uid,
          confirm: (_, _) async {
            confirms++;
            if (invalid == 'lateUid') uid = 'other';
            if (invalid == 'lateOff') await db.deactivateChat();
            return (mealId: 42, acknowledged: true);
          },
          lookup: (_, _) async => null,
          show: (_, _) async {
            shows++;
          },
          cancel: (_) async {},
        );
        expect(handled, invalid.startsWith('late'));
        expect(confirms, invalid.startsWith('late') ? 1 : 0);
        expect(shows, 0);
      },
    );
  }
  test(
    'revocation during native feedback cancels the displayed status and retains failed cancellation intent',
    () async {
      for (final failCancel in [false, true]) {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final scope = jsonEncode(['child', 'family', 'e']);
        await db.activateChat('child', scope, 'stamp');
        final payload = {
          'type': 'familyChat',
          ...await db.activeChat(),
          'messageId': 'request',
        };
        var cancelled = 0;
        try {
          await handleFamilyChatConsumption(
            db: db,
            api: _Api(),
            payload: payload,
            currentUid: () => 'child',
            confirm: (_, _) async => (mealId: 42, acknowledged: true),
            lookup: (_, _) async => null,
            show: (_, _) async {
              await db.fence.block();
            },
            cancel: (_) async {
              cancelled++;
              if (failCancel) throw StateError('OS unavailable');
            },
          );
          expect(cancelled, 1);
          expect(
            await db.hasCancellationIntent(familyChatNotice(scope, 'request')),
            failCancel,
          );
        } finally {
          await db.close();
        }
      }
    },
  );
  test(
    'only child treatment notifications offer a distinct consumption action and bound timeout',
    () {
      final guard = {'uid': 'child', 'scope': 'scope', 'stamp': 'stamp'};
      var elapsed = 0;
      final message = {
        'id': 'request',
        'kind': 'lowTreatment',
        'senderUid': 'mom',
        'names': {'mom': 'Mama'},
        'text': 'Food',
        'sentAt': 1000,
        'expiresAt': 100000,
        'treatment': {'validUntil': 5000},
      };
      AndroidNotificationDetails details(
        String role,
        Map<String, dynamic> source,
      ) => AndroidFamilyChatPresenter.messageEvent(
        FamilyChatPushView(
          guard,
          {
            'serverTime': 1000,
            'members': [
              {'uid': 'child', 'role': role, 'displayName': 'Dziecko'},
            ],
          },
          source,
          'mom',
          elapsedMilliseconds: () => elapsed,
        ),
      ).toAndroidNotificationDetails();
      final treatment = details('child', message);
      expect(treatment.timeoutAfter, 4000);
      final consume = treatment.actions!.singleWhere(
        (action) => action.id == 'family_chat_consume',
      );
      expect(consume.inputs, isEmpty);
      expect(consume.cancelNotification, false);
      final reply = treatment.actions!.singleWhere(
        (action) => action.id == 'family_chat_reply',
      );
      expect(reply.inputs.single.choices, ['Zjem', 'Nie mam']);
      expect(
        details(
          'managingCaregiver',
          message,
        ).actions!.any((action) => action.id == 'family_chat_consume'),
        false,
      );
      expect(
        details('child', {
          ...message,
          'treatmentResult': {'uid': 'child'},
        }).actions!.any((action) => action.id == 'family_chat_consume'),
        false,
      );
      final ordinary = details('child', {
        ...message,
        'kind': 'question',
        'answers': ['Zjadłem'],
      });
      expect(ordinary.actions, hasLength(1));
      expect(ordinary.actions!.single.id, 'family_chat_reply');
      expect(ordinary.actions!.single.inputs.single.choices, ['Zjadłem']);
      elapsed = 3999;
      expect(details('child', message).timeoutAfter, 1);
      elapsed = 4000;
      expect(
        details(
          'child',
          message,
        ).actions!.any((action) => action.id == 'family_chat_consume'),
        false,
      );
      elapsed = 60000;
      expect(details('child', message).timeoutAfter, 1);
      expect(
        details(
          'child',
          message,
        ).actions!.any((action) => action.id == 'family_chat_consume'),
        false,
      );
    },
  );
}
