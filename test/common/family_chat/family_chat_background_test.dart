import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_background.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_guard_fence.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_notification_platform.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_presenter.dart';
import 'package:diabeatthis/common/family_chat/notifications/family_chat_registration.dart';
import 'package:diabeatthis/common/notifications/firebase_background_handler.dart';
import 'package:diabeatthis/core/notifications/domain/events/family_chat_notification.dart';
import 'package:diabeatthis/core/notifications/mappers/android_notification_details_mapper.dart';
import 'package:drift/native.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api implements FamilyChatApi {
  bool enabled = true, failSend = false;
  bool failReadAck = false;
  bool offline = false;
  Future<void> Function()? onConfig;
  Future<void> Function()? onSend;
  int ticket = 0, sendCount = 0;
  Completer<void>? statesGate;
  CallableFailure? sendRejection;
  final requests = <(String, Map<String, Object?>)>[];
  final message = <String, dynamic>{
    'id': 'question',
    'senderUid': 'mom',
    'conversationId': 'direct_opaque',
    'participants': {'child': 'epoch', 'mom': 'm'},
    'names': {'mom': 'Mama'},
    'kind': 'question',
    'text': 'Masz śniadanie?',
    'answers': ['Mam'],
    'sequence': 1,
    'sentAt': 900,
    'expiresAt': 10000,
    'receipts': {
      'child': <String, dynamic>{'deliveredAt': null, 'readAt': null},
    },
  };
  final sent = <String, Map<String, dynamic>>{};

  /// Simulates the transport's identity resolution for one operation.
  String? identityHeldOperation;
  Completer<void>? identityEntered, identityRelease;
  final rejected = <String>[];
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    requests.add((operation, Map.of(data)));
    if (operation == identityHeldOperation) {
      identityHeldOperation = null;
      identityEntered!.complete();
      await identityRelease!.future;
    }
    if (allowRequest != null && !await allowRequest()) {
      rejected.add(operation);
      throw const CallableFailure('cancelled');
    }
    switch (operation) {
      case 'getFamilyChatConfig':
        await onConfig?.call();
        if (offline) throw const CallableFailure('unavailable');
        return {
          'uid': 'child',
          'familyId': 'f',
          'epoch': 'epoch',
          'serverTime': 1000,
          'account': {'enabled': enabled, 'revision': 0},
          'policy': {
            'enabled': true,
            'revision': 0,
            'retention': 'week',
            'shortenings': [],
          },
          'members': [
            {'uid': 'child', 'role': 'child', 'displayName': 'Dziecko'},
            {'uid': 'mom', 'role': 'managingCaregiver', 'displayName': 'Mama'},
          ],
        };
      case 'fetchFamilyChatMessageStates':
        if (statesGate != null) await statesGate!.future;
        return {
          'messages': [
            for (final row in [message, ...sent.values])
              if ((data['ids'] as List).contains(row['id']) &&
                  (row['expiresAt'] as int) > 1000)
                jsonDecode(jsonEncode(row)),
          ],
          'serverTime': 1000,
        };
      case 'fetchFamilyChatConversations':
        return {'conversations': [], 'cursor': '', 'hasMore': false};
      case 'fetchFamilyChatShortcuts':
        return {'items': null, 'revision': 0, 'order': [], 'orderRevision': 0};
      case 'fetchFamilyChatMessages':
        final rows = data['targetUid'] == 'mom'
            ? [message, ...sent.values]
                  .where(
                    (row) =>
                        (row['sequence'] as int) > (data['after'] as int? ?? 0),
                  )
                  .toList()
            : <Map<String, dynamic>>[];
        return {
          'messages': rows,
          'cursor': rows.lastOrNull?['sequence'] ?? data['after'] ?? 0,
          'hasMore': false,
        };
      case 'acknowledgeFamilyChatMessages':
        for (final item in data['items'] as List) {
          if (item['read'] == true && failReadAck) {
            throw const CallableFailure('unavailable');
          }
          final receipt = (message['receipts'] as Map)['child'] as Map;
          receipt['deliveredAt'] ??= 1000;
          if (item['read'] == true) receipt['readAt'] ??= 1000;
        }
        return {
          'acknowledged': ['question'],
          'ignored': [],
        };
      case 'reserveFamilyChatOperations':
        return {
          'tickets': [
            {
              'id': 'ticket${++ticket}',
              'token': 'ticket$ticket',
              'expiresAt': 9000,
            },
          ],
        };
      case 'sendFamilyChatMessage':
        sendCount++;
        if (sendRejection != null) throw sendRejection!;
        final id = data['ticket'] as String;
        final value = sent.putIfAbsent(
          id,
          () => {
            'id': id,
            'text': data['text'],
            'kind': 'answer',
            'replyTo': data['replyTo'],
            'senderUid': 'child',
            'sequence': 2,
            'sentAt': 1000,
            'expiresAt': 9000,
            'receipts': {
              'mom': {'deliveredAt': null, 'readAt': null},
            },
          },
        );
        if (failSend) throw const CallableFailure('unavailable');
        await onSend?.call();
        return {'message': value};
    }
    throw StateError(operation);
  }
}

class _Presenter implements FamilyChatPushPresenter {
  final shown = <FamilyChatPushView>[];
  final cancelled = <FamilyChatNotice>[];
  final replyEffects = <(String, FamilyChatNotice)>[];
  bool failReplyUpdate = false;
  bool failCancel = false;
  int pendingCount = 0;
  @override
  Future<void> pending(
    FamilyChatPushView view, {
    required bool needsTicket,
  }) async {
    pendingCount++;
  }

  @override
  Future<void> show(FamilyChatPushView view) async {
    shown.add(view);
  }

  @override
  Future<void> cancel(FamilyChatNotice notice) async {
    replyEffects.add(('cancel', notice));
    if (failCancel) throw StateError('OS unavailable');
    cancelled.add(notice);
  }

  @override
  Future<void> replyCompleted(
    FamilyChatNotice notice,
    FamilyChatPushView view,
  ) async {
    replyEffects.add(('reply', notice));
    if (failReplyUpdate) throw StateError('OS update unavailable');
  }
}

/// Holds the durable history read inside allowRequest once armed.
class _GatedHistoryDb extends FamilyChatDatabase {
  _GatedHistoryDb() : super(NativeDatabase.memory());
  Completer<void>? historyEntered, historyRelease;
  @override
  Future<bool> historyAllows(String scope, int generation) async {
    final release = historyRelease;
    if (release != null) {
      historyRelease = null;
      historyEntered!.complete();
      await release.future;
    }
    return super.historyAllows(scope, generation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final scope = jsonEncode(['child', 'f', 'epoch']);
  const data = {
    'type': 'familyChat',
    'uid': 'child',
    'familyId': 'f',
    'epoch': 'epoch',
    'messageId': 'question',
  };
  test(
    'foreground recovery presents a saved push before flushing its receipt',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = _Api();
      final presenter = _Presenter();
      addTearDown(db.close);
      await db.saveMessage(scope, 'mom', api.message, serverNow: 1000);
      await db.queueReceipt(scope, 'question', false);
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        notificationPresenter: presenter,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      addTearDown(session.dispose);

      await session.start(foreground: true);

      expect(presenter.shown.single.message['id'], 'question');
      expect(api.message['receipts']['child']['deliveredAt'], 1000);
      expect(session.unreadCount, 1);
    },
  );

  test('notification reply updates the running chat badge offline', () async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    final api = _Api();
    api.sent['other'] = {
      ...Map<String, dynamic>.from(jsonDecode(jsonEncode(api.message)) as Map),
      'id': 'other',
      'sequence': 2,
    };
    final presenter = _Presenter();
    DateTime clock() => DateTime.fromMillisecondsSinceEpoch(1000);
    final session = FamilyChatSession(
      uid: 'child',
      api: api,
      db: db,
      isCurrentAccount: () => true,
      notificationPresenter: presenter,
      clock: clock,
    );
    addTearDown(db.close);
    addTearDown(session.dispose);
    await session.start(foreground: true);
    expect(session.unreadCount, 2);

    final badgeChanged = Completer<void>();
    session.addListener(() {
      if (session.unreadCount == 1 && !badgeChanged.isCompleted) {
        badgeChanged.complete();
      }
    });
    api.offline = true;
    final worker = FamilyChatBackground(
      db: db,
      api: api,
      currentUid: () => 'child',
      presenter: presenter,
      clock: clock,
    );
    final notice = presenter.shown.singleWhere(
      (view) => view.message['id'] == 'question',
    );
    expect(await worker.reply(notice.payload, 'Mam'), isTrue);
    await badgeChanged.future.timeout(const Duration(seconds: 2));
    expect(await db.locallyRead(scope, 'question'), isTrue);
    expect(await db.locallyRead(scope, 'other'), isFalse);
  });

  test(
    'foreground sync presents incoming questions and answers without push',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = _Api();
      final presenter = _Presenter();
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
        notificationPresenter: presenter,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      addTearDown(db.close);
      addTearDown(session.dispose);
      await session.start(foreground: true);
      expect(presenter.shown.map((view) => view.message['kind']), ['question']);

      final push = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      await push.receive(data);
      expect(presenter.shown, hasLength(1));

      api.message
        ..['id'] = 'answer'
        ..['kind'] = 'answer'
        ..['sequence'] = 2;
      api.message['receipts']['child']['deliveredAt'] = null;
      await session.synchronize();
      expect(presenter.shown.map((view) => view.message['kind']), [
        'question',
        'answer',
      ]);
    },
  );

  test(
    'retention shortening durably cancels a notice and suppresses late delivery',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chat-retention-notice-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/chat.sqlite');
      final first = FamilyChatDatabase(NativeDatabase(file));
      final api = _Api();
      api.message['expiresAt'] = 3 * 86400000;
      final notice = familyChatNotice(scope, 'question');
      final legacy = (id: 8042, tag: notice.tag);
      final otherScope = jsonEncode(['other', 'f', 'epoch']);
      final other = familyChatNotice(otherScope, 'question');
      await first.saveMessage(scope, 'mom', api.message);
      await first.saveMessage(otherScope, 'mom', api.message);
      await first.rememberNotification(
        scope,
        legacy.id,
        'one',
        tag: legacy.tag,
      );
      await first.rememberNotification(
        otherScope,
        other.id,
        'other',
        tag: other.tag,
      );
      await first.applyRetention(scope, {
        'revision': 1,
        'retention': 'day',
        'shortenings': [
          {'revision': 1, 'days': 1},
        ],
      });
      expect(await first.historyCancellationIntents(scope), [legacy]);
      expect(await first.historyCancellationIntents(otherScope), isEmpty);
      await FamilyChatNotificationPlatform.cancel(
        first,
        [legacy],
        operation: (_) async => throw StateError('OS unavailable'),
        keepTrying: () => false,
      );
      await first.close();

      final db = FamilyChatDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final outstanding = await db.historyCancellationIntents(scope);
      expect(outstanding, [legacy]);
      final cancelled = <FamilyChatNotice>[];
      await FamilyChatNotificationPlatform.cancel(
        db,
        outstanding,
        operation: (notice) async => cancelled.add(notice),
      );
      expect(cancelled, [legacy]);
      expect(await db.historyCancellationIntents(scope), isEmpty);
      expect(await db.hasCancellationIntent(other), true);
      await db.confirmCancelled(other);
      await db.activateChat('child', scope, 'two');
      final presenter = _Presenter();
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      await worker.receive(data);
      expect(presenter.shown, isEmpty);
    },
  );

  test(
    'an authoritative own read cancels an old notice and stale fetch cannot show it again',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api();
      final notice = familyChatNotice(scope, 'question');
      await db.activateChat('child', scope, 'one');
      await db.saveMessage(scope, 'mom', api.message);
      await db.rememberNotification(scope, notice.id, 'one', tag: notice.tag);
      for (var sequence = 2; sequence <= 52; sequence++) {
        await db.saveMessage(scope, 'mom', {
          ...api.message,
          'id': 'later-$sequence',
          'sequence': sequence,
        });
      }
      expect(
        (await db.messages(scope, 'mom')).any((row) => row['id'] == 'question'),
        false,
      );
      expect(await db.notificationMessageIds(scope, 'mom'), ['question']);
      await db.saveMessage(scope, 'mom', {
        ...api.message,
        'receipts': {
          'child': {'readAt': null},
          'other': {'readAt': 1001},
        },
      });
      expect(await db.historyCancellationIntents(scope), isEmpty);
      await db.saveMessage(scope, 'mom', {
        ...api.message,
        'receipts': {
          'child': {'readAt': 1001},
        },
      });
      expect(await db.historyCancellationIntents(scope), [notice]);
      expect(
        await db.prepareNotification(await db.activeChat(), notice),
        false,
      );
      await db.confirmCancelled(notice);
      final presenter = _Presenter();
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      expect(await worker.receive(data), true);
      expect(presenter.shown, isEmpty);
      expect(
        (await db.message(scope, 'question'))?['receipts']?['child']?['readAt'],
        1001,
      );
    },
  );
  test(
    'message IDs and tags stay scoped and match cancellation after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'family-chat-notice-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/chat.sqlite');
      final db = FamilyChatDatabase(NativeDatabase(file));
      final api = _Api();
      final presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      expect(await worker.receive(data), true);
      final shown = presenter.shown.single;
      final event = AndroidFamilyChatPresenter.messageEvent(shown);
      final notice = familyChatNotice(scope, 'question');
      expect((id: event.id, tag: event.tag), notice);
      expect(event.toPayload()['messageId'], 'question');
      expect(event.toPayload()['scope'], scope);
      expect(familyChatNotice(scope, 'another-question').id, isNot(notice.id));
      expect(
        familyChatNotice(jsonEncode(['other', 'f', 'epoch']), 'question').id,
        isNot(notice.id),
      );
      await db.close();

      final reopened = FamilyChatDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(await reopened.cancellationIntents(), [notice]);
      expect(familyChatNotice(scope, 'question'), notice);
    },
  );
  for (final delayed in ['config', 'states']) {
    test('near-expiry instruction accounts for delayed $delayed', () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.activateChat('child', scope, 'stamp');
      final api = _Api(), presenter = _Presenter();
      api.message['kind'] = 'lowTreatment';
      api.message['treatment'] = {'validUntil': 1050};
      if (delayed == 'config') {
        api.onConfig = () =>
            Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (delayed == 'states') {
        api.statesGate = Completer<void>();
        api.onConfig = () async {
          Timer(const Duration(milliseconds: 80), api.statesGate!.complete);
        };
      }
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
        clock: () => DateTime(2000),
      );
      final received = await worker.receive(data);
      expect(received, false);
      expect(presenter.shown, isEmpty);
    });
  }
  for (final invalid in ['expired', 'revoked']) {
    test(
      'offline reply cannot dispatch after parent expiry or revocation: $invalid',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final api = _Api(), presenter = _Presenter();
        await db.activateChat('child', scope, 'one');
        final worker = FamilyChatBackground(
          db: db,
          api: api,
          currentUid: () => 'child',
          presenter: presenter,
        );
        await worker.receive(data);
        api.offline = true;
        expect(await worker.reply(presenter.shown.single.payload, 'Mam'), true);
        api.offline = false;
        if (invalid == 'expired') {
          api.message['expiresAt'] = 999;
        } else {
          api.enabled = false;
        }
        final session = FamilyChatSession(
          uid: 'child',
          api: api,
          db: db,
          isCurrentAccount: () => true,
          clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
        );
        addTearDown(session.dispose);
        await session.start();
        await session.synchronize();
        expect(api.sent, isEmpty);
        if (invalid == 'expired') {
          final id = (await db.outbox(scope)).single.read<String>('id');
          await expectLater(session.retry('mom', id), throwsStateError);
          expect(
            (await db.outbox(scope)).single.read<String>('error'),
            'expired',
          );
        } else {
          expect(await db.outbox(scope), isEmpty);
        }
      },
    );
  }
  for (final scenario in ['unsigned', 'signed', 'missing-cache']) {
    final withTicket = scenario == 'signed';
    test(
      'offline watch reply is durable before HTTP and foreground restart sends it once: $scenario',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'chat-offline-reply-',
        );
        FamilyChatDatabase open() => FamilyChatDatabase(
          NativeDatabase.createInBackground(
            File('${directory.path}/chat.sqlite'),
          ),
          SqliteChatGuardFence(
            NativeDatabase.createInBackground(
              File('${directory.path}/guard.sqlite'),
            ),
          ),
        );
        var db = open();
        final api = _Api(), presenter = _Presenter();
        FamilyChatSession? session;
        try {
          await db.activateChat('child', scope, 'one');
          final worker = FamilyChatBackground(
            db: db,
            api: api,
            currentUid: () => 'child',
            presenter: presenter,
          );
          await worker.receive(data);
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.setMetadata('account:child', {
            ...await api.call('getFamilyChatConfig', {}),
            '_observedLocalAt': now,
            '_serverOffset': 1000 - now,
            '_lastServerNow': 1000,
          });
          if (withTicket) {
            await db.addTickets(scope, [
              {
                'id': 'offline-ticket',
                'token': 'offline-ticket',
                'expiresAt': 9000,
              },
            ]);
          }
          if (scenario == 'missing-cache') {
            await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
              'account:child',
            ]);
          }
          api.offline = true;
          api.onConfig = () async {
            expect(
              (await db.outbox(scope)).single.read<String>('payload'),
              contains('Mam'),
            );
          };
          expect(
            await worker.reply(presenter.shown.single.payload, 'Mam'),
            true,
          );
          expect(api.sent, isEmpty);
          final operation = (await db.outbox(scope)).single;
          expect(
            operation.readNullable<String>('error'),
            withTicket ? null : 'needs-ticket',
          );
          expect(presenter.pendingCount, 1);
          await db.close();
          db = open();
          api.offline = false;
          api.onConfig = null;
          if (!withTicket) {
            final redelivery = FamilyChatBackground(
              db: db,
              api: api,
              currentUid: () => 'child',
              presenter: presenter,
            );
            expect(
              await redelivery.reply(presenter.shown.single.payload, 'Mam'),
              true,
            );
            expect(api.sent, isEmpty);
            expect(
              (await db.outbox(scope)).single.read<String>('error'),
              'needs-ticket',
            );
          }
          session = FamilyChatSession(
            uid: 'child',
            api: api,
            db: db,
            isCurrentAccount: () => true,
            clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
          );
          await session.start();
          await session.synchronize();
          if (!withTicket) {
            expect(api.sent, isEmpty);
            final draft = (await db.outbox(scope)).single;
            expect(draft.read<String>('error'), 'needs-ticket');
            await session.retry('mom', draft.read<String>('id'));
          }
          expect(api.sent.length, 1);
          expect(api.sent.values.single['text'], 'Mam');
          expect(await db.outbox(scope), isEmpty);
        } finally {
          session?.dispose();
          await db.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }
  test(
    'rollout disabled worker cannot fetch, present or reply and upgrade cleanup closes the old guard',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
        rolloutEnabled: false,
      );
      api.offline = true;
      expect(await worker.receive(data), false);
      expect(await worker.reply({'type': 'familyChat'}, 'Mam'), false);
      var revoked = 0;
      await FamilyChatRegistrationJournal(db).prepare('child', scope, {
        'enabled': true,
        'token': 'token',
        'installationId': 'install',
        'counter': 1,
        'revocationToken': 'proof',
      });
      await routeFamilyFirebaseMessage(
        const RemoteMessage(data: data),
        initialize: () async {
          throw StateError('Firebase initialization unavailable');
        },
        chat: (_) => disableFamilyChatRollout(
          db,
          revoke: (_) async {
            revoked++;
            return {'ok': true};
          },
        ),
        meal: (_) async {
          fail('Chat must not use the meal handler');
        },
      );
      expect((await db.activeChat())['enabled'], false);
      expect(revoked, 1);
      expect(presenter.shown, isEmpty);
      expect(api.sent, isEmpty);
    },
  );
  test(
    'signout revocations remain durable on failure and preserve the new account registration',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final journal = FamilyChatRegistrationJournal(db);
      Map<String, dynamic> registration(int counter) => {
        'enabled': true,
        'token': 'token$counter',
        'installationId': 'install',
        'counter': counter,
        'revocationToken': 'proof$counter',
      };
      await journal.prepare('child', scope, registration(1));
      await journal.prepare('mom', 'new-scope', registration(2));
      await expectLater(
        journal.revokeObsolete(
          currentUid: 'mom',
          enabled: true,
          currentScope: 'new-scope',
          revoke: (_) async {
            throw const CallableFailure('unavailable');
          },
        ),
        throwsA(isA<CallableFailure>()),
      );
      final removed = <int>[];
      await journal.revokeObsolete(
        currentUid: 'mom',
        enabled: true,
        currentScope: 'new-scope',
        revoke: (data) async {
          removed.add(data['counter'] as int);
          return {'ok': true};
        },
      );
      expect(removed, [1]);
      await journal.revokeObsolete(
        currentUid: null,
        enabled: false,
        revoke: (data) async {
          removed.add(data['counter'] as int);
          return {'ok': true};
        },
      );
      expect(removed, [1, 2]);
    },
  );
  test(
    'a visible conversation receives cache and delivery ACK without an OS alert',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
        shouldPresent: (target) => target != 'mom',
      );
      expect(await worker.receive(data), true);
      expect(presenter.shown, isEmpty);
      expect(api.message['receipts']['child']['deliveredAt'], 1000);
      expect(api.message['receipts']['child']['readAt'], isNull);
    },
  );
  test(
    'push fetches authorized content, caches before delivered ACK, and deduplicates OS display',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      expect(await worker.receive(data), true);
      expect(await worker.receive(data), true);
      expect(presenter.shown.length, 1);
      expect(
        (await db.messages(scope, 'mom')).single['text'],
        'Masz śniadanie?',
      );
      expect(api.message['receipts']['child']['deliveredAt'], 1000);
      expect(api.message['receipts']['child']['readAt'], isNull);
    },
  );
  for (final condition in ['off', 'wrongUid', 'wrongEpoch', 'expired']) {
    test('push refuses unauthorized or expired content: $condition', () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      if (condition == 'off') api.enabled = false;
      if (condition == 'expired') api.message['expiresAt'] = 999;
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => condition == 'wrongUid' ? 'mom' : 'child',
        presenter: presenter,
      );
      expect(
        await worker.receive({
          ...data,
          if (condition == 'wrongEpoch') 'epoch': 'other',
        }),
        false,
      );
      expect(presenter.shown, isEmpty);
      expect(await db.messages(scope, 'mom'), isEmpty);
    });
  }
  test(
    'a late UID switch during content fetch cannot cache or show the old message',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      var uid = 'child';
      await db.activateChat(uid, scope, 'one');
      api.statesGate = Completer<void>();
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => uid,
        presenter: presenter,
      );
      final receiving = worker.receive(data);
      await Future<void>.delayed(Duration.zero);
      uid = 'mom';
      await db.deactivateChat();
      api.statesGate!.complete();
      expect(await receiving, false);
      expect(presenter.shown, isEmpty);
      expect(await db.messages(scope, 'mom'), isEmpty);
    },
  );
  test(
    'watch reply uses one durable operation across duplicate callbacks and lost send responses',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      await worker.receive(data);
      final payload = presenter.shown.single.payload;
      api.failSend = true;
      expect(await worker.reply(payload, 'Mam'), true);
      expect(presenter.pendingCount, 1);
      expect((await db.outbox(scope)).length, 1);
      expect(await worker.reply(payload, 'Nie mam'), false);
      expect(api.sent.length, 1);
      api.failSend = false;
      expect(await worker.reply(payload, 'Mam'), true);
      expect(await worker.reply(payload, 'Mam'), true);
      expect(await worker.reply(payload, 'Nie mam'), false);
      expect(api.sent.length, 1);
      expect(presenter.replyEffects, [
        ('reply', familyChatNotice(scope, 'question')),
      ]);
      expect(await db.outbox(scope), isEmpty);
      expect(await db.locallyRead(scope, 'question'), true);
      expect(api.message['receipts']['child']['readAt'], 1000);
    },
  );
  test('confirmed reply closes the notice even if read ACK fails', () async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _Api()..failReadAck = true;
    final presenter = _Presenter()
      ..failReplyUpdate = true
      ..failCancel = true;
    await db.activateChat('child', scope, 'one');
    final worker = FamilyChatBackground(
      db: db,
      api: api,
      currentUid: () => 'child',
      presenter: presenter,
    );
    await worker.receive(data);
    final payload = presenter.shown.single.payload;
    final replies = await Future.wait([
      worker.reply(payload, 'Mam'),
      worker.reply(payload, 'Nie mam'),
    ]);
    expect(replies.where((accepted) => accepted), hasLength(1));
    expect(api.sent, hasLength(1));
    expect(await db.outbox(scope), isEmpty);
    expect(presenter.pendingCount, 0);
    final notice = familyChatNotice(scope, 'question');
    expect(presenter.replyEffects, [('reply', notice), ('cancel', notice)]);
    expect(await db.historyCancellationIntents(scope), [notice]);
    presenter.failCancel = false;
    final original = api.sent.values.single['text'] as String;
    expect(await worker.reply(payload, original), true);
    expect(api.sendCount, 1);
    expect(presenter.cancelled, [notice]);
    expect(presenter.replyEffects, [
      ('reply', notice),
      ('cancel', notice),
      ('cancel', notice),
    ]);
    expect(await db.historyCancellationIntents(scope), isEmpty);
  });

  test('a UID switch after send does not show a reply update', () async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _Api(), presenter = _Presenter();
    var uid = 'child';
    await db.activateChat(uid, scope, 'one');
    final worker = FamilyChatBackground(
      db: db,
      api: api,
      currentUid: () => uid,
      presenter: presenter,
    );
    await worker.receive(data);
    api.onSend = () async => uid = 'other';
    expect(await worker.reply(presenter.shown.single.payload, 'Mam'), true);
    expect(api.sent, hasLength(1));
    expect(presenter.replyEffects, isEmpty);
  });

  group('RemoteInput reply admission after identity', () {
    // Starts a valid reply, holds simulated identity for the send, applies
    // [whileHeld] and only then releases identity.
    Future<_Api> heldReply(
      Future<void> Function(FamilyChatDatabase db, void Function(String) setUid)
      whileHeld,
    ) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      var uid = 'child';
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => uid,
        presenter: presenter,
      );
      expect(await worker.receive(data), true);
      final payload = presenter.shown.single.payload;
      api
        ..identityHeldOperation = 'sendFamilyChatMessage'
        ..identityEntered = Completer<void>()
        ..identityRelease = Completer<void>();
      // Attach the outcome handler before releasing anything.
      final done = worker
          .reply(payload, 'Mam')
          .then<void>((_) {}, onError: (Object _) {});
      try {
        await api.identityEntered!.future.timeout(const Duration(seconds: 5));
        await whileHeld(db, (next) => uid = next);
      } finally {
        if (!api.identityRelease!.isCompleted) api.identityRelease!.complete();
      }
      await done;
      return api;
    }

    test('unchanged admission still sends once (control)', () async {
      final api = await heldReply((_, _) async {});
      expect(api.sendCount, 1);
      expect(api.rejected, isNot(contains('sendFamilyChatMessage')));
    });

    test('local OFF while identity is held sends nothing', () async {
      final api = await heldReply((db, _) async {
        await db.fence.revokeAccount('child');
      });
      expect(api.sendCount, 0);
      expect(api.sent, isEmpty);
      expect(api.rejected, contains('sendFamilyChatMessage'));
    });

    test('OFF then ON with a new stamp before release sends nothing', () async {
      final api = await heldReply((db, _) async {
        final token = await db.fence.revokeAccount('child');
        await db.fence.clearAccountRevocation('child', token);
        final version = (await db.fence.read())['version'] as String;
        expect(await db.fence.activate(version, 'child', scope, 'two'), true);
        expect(await db.fence.accountRevocation('child'), isNull);
      });
      expect(api.sendCount, 0);
      expect(api.rejected, contains('sendFamilyChatMessage'));
    });

    test('account switch before release sends nothing', () async {
      final api = await heldReply((_, setUid) async => setUid('other'));
      expect(api.sendCount, 0);
      expect(api.rejected, contains('sendFamilyChatMessage'));
    });

    test('durable history clear before release sends nothing', () async {
      final api = await heldReply((db, _) async {
        await db.observeHistoryGeneration(scope, 1);
        expect(await db.historyAllows(scope, 0), false);
      });
      expect(api.sendCount, 0);
      expect(api.rejected, contains('sendFamilyChatMessage'));
    });

    for (final sameUidOffOn in [false, true]) {
      test(
        sameUidOffOn
            ? 'same-UID OFF->ON (new stamp) during the held guarded history read sends nothing'
            : 'account switch during the final history read is caught by the last recheck',
        () async {
          final db = _GatedHistoryDb();
          addTearDown(db.close);
          final api = _Api(), presenter = _Presenter();
          var uid = 'child';
          await db.activateChat('child', scope, 'one');
          final worker = FamilyChatBackground(
            db: db,
            api: api,
            currentUid: () => uid,
            presenter: presenter,
          );
          expect(await worker.receive(data), true);
          final payload = presenter.shown.single.payload;
          api
            ..identityHeldOperation = 'sendFamilyChatMessage'
            ..identityEntered = Completer<void>()
            ..identityRelease = Completer<void>();
          final historyRelease = Completer<void>();
          final done = worker
              .reply(payload, 'Mam')
              .then<void>((_) {}, onError: (Object _) {});
          try {
            await api.identityEntered!.future.timeout(
              const Duration(seconds: 5),
            );
            db
              ..historyEntered = Completer<void>()
              ..historyRelease = historyRelease;
            final historyEntered = db.historyEntered!;
            api.identityRelease!.complete();
            await historyEntered.future.timeout(const Duration(seconds: 5));
            if (sameUidOffOn) {
              // History is held INSIDE withChatGuard's writer. Another actor
              // latches OFF and re-admits the same UID with a new stamp through
              // the independent fence (no writer lock => no deadlock).
              final token = await db.fence.revokeAccount('child');
              expect(
                await db.fence.clearAccountRevocation('child', token),
                true,
              );
              final version = (await db.fence.read())['version'] as String;
              expect(
                await db.fence.activate(version, 'child', scope, 'two'),
                true,
              );
              expect((await db.fence.read())['stamp'], 'two');
            } else {
              uid = 'other';
            }
          } finally {
            if (!api.identityRelease!.isCompleted) {
              api.identityRelease!.complete();
            }
            if (!historyRelease.isCompleted) historyRelease.complete();
            db.historyRelease = null;
          }
          await done;
          expect(api.sendCount, 0);
          expect(api.rejected, contains('sendFamilyChatMessage'));
        },
      );
    }
  });

  test(
    'successful reply update defers ordinary cancellation until timeout',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      await worker.receive(data);
      final payload = presenter.shown.single.payload;
      final notice = familyChatNotice(scope, 'question');
      expect(await worker.reply(payload, 'Mam'), true);
      expect(await worker.reply(payload, 'Mam'), true);
      expect(presenter.replyEffects, [('reply', notice)]);
      expect(await db.historyCancellationIntents(scope), isEmpty);
      expect(await db.cancellationIntents(), [notice]);
      expect(
        await db.historyCancellationIntents(
          scope,
          now: DateTime.now().millisecondsSinceEpoch + 3000,
        ),
        [notice],
      );
      expect(api.sendCount, 1);
    },
  );

  test(
    'an already synchronized answer blocks a stale notification action',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      await worker.receive(data);
      final payload = presenter.shown.single.payload;
      await db.saveMessage(scope, 'mom', {
        ...api.message,
        'id': 'from-other-device',
        'kind': 'answer',
        'senderUid': 'child',
        'replyTo': 'question',
      });
      expect(await worker.reply(payload, 'Nie mam'), false);
      expect(api.sent, isEmpty);
      expect(await db.historyCancellationIntents(scope), [
        familyChatNotice(scope, 'question'),
      ]);
    },
  );
  test(
    'RemoteInput preserves exactly zero, one and several proposed answers and redacts lock screen',
    () async {
      final api = _Api();
      final config = await api.call('getFamilyChatConfig', {});
      for (final answers in [
        <String>[],
        ['Mam'],
        ['Mam', 'Nie mam'],
      ]) {
        final view = FamilyChatPushView(
          {'uid': 'child', 'scope': scope, 'stamp': 'one'},
          config,
          {...api.message, 'answers': answers},
          'mom',
        );
        final details = AndroidFamilyChatPresenter.messageEvent(
          view,
        ).toAndroidNotificationDetails();
        expect(details.actions!.single.inputs.single.choices, answers);
        expect(details.actions!.single.allowGeneratedReplies, false);
        expect(details.visibility, NotificationVisibility.private);
        expect(details.onlyAlertOnce, true);
        expect(details.tag, view.notice.tag);
        expect(details.importance, Importance.high);
        expect(details.priority, Priority.high);
        expect(details.category, AndroidNotificationCategory.message);
        expect(details.styleInformation, isA<MessagingStyleInformation>());
        final completed = AndroidFamilyChatPresenter.replyCompletedEvent(
          view.notice,
          view,
        );
        final completedDetails = completed.toAndroidNotificationDetails();
        expect(completed.id, view.notice.id);
        expect(completedDetails.tag, view.notice.tag);
        expect(completedDetails.silent, true);
        expect(
          completedDetails.timeoutAfter,
          familyChatReplyAcknowledgmentTimeoutMs,
        );
        expect(completedDetails.actions, isEmpty);
        expect(completedDetails.styleInformation, isNull);
      }
    },
  );
  test('pending reply keeps the original Android channel defaults', () {
    const event = FamilyChatNotificationEvent(
      id: 8042,
      tag: 'pending-reply',
      title: 'Pending reply',
      body: 'Reply queued',
      payload: {'type': 'familyChat'},
    );
    final details = event.toAndroidNotificationDetails();
    expect(details.channelId, 'family_chat_messages');
    expect(details.tag, event.tag);
    expect(details.visibility, NotificationVisibility.private);
    expect(details.onlyAlertOnce, true);
    expect(details.importance, Importance.defaultImportance);
    expect(details.priority, Priority.defaultPriority);
    expect(details.category, isNull);
    expect(details.styleInformation, isNull);
    expect(details.channelDescription, isNull);
    expect(details.actions, isNull);
    expect(details.timeoutAfter, isNull);
    expect(details.silent, false);
  });

  group('B1 shared reply policy', () {
    Future<
      (FamilyChatDatabase, _Api, FamilyChatBackground, Map<String, dynamic>)
    >
    received({void Function(_Api)? seed}) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api(), presenter = _Presenter();
      seed?.call(api);
      await db.activateChat('child', scope, 'one');
      final worker = FamilyChatBackground(
        db: db,
        api: api,
        currentUid: () => 'child',
        presenter: presenter,
      );
      await worker.receive(data);
      return (db, api, worker, presenter.shown.single.payload);
    }

    // Localized RemoteInput promise choices (C1) are ordinary answers; only
    // the dedicated family_chat_consume action may reach the clinical path.
    for (final input in ['Zjem', 'Nie mam', "I'll eat it", "I don't have it"]) {
      test('lowTreatment promise "$input" stores only an answer', () async {
        final (db, api, worker, payload) = await received(
          seed: (api) => api.message
            ..['kind'] = 'lowTreatment'
            ..['text'] = '2 × Candy · 6.5 g WW · zapis 7 g'
            ..['answers'] = <String>[]
            ..['treatment'] = {
              'foodName': 'Candy',
              'quantity': 2,
              'unit': 'piece',
              'gramsPerUnit': 5,
              'carbsPer100g': 65,
              'carbsPerUnit': 3.25,
              'carbs': 6.5,
              'deliveryCarbs': 7,
              'validUntil': 9500,
            },
        );
        expect(await worker.reply(payload, input), true);
        final sends = api.requests
            .where((request) => request.$1 == 'sendFamilyChatMessage')
            .toList();
        expect(sends, hasLength(1));
        expect(sends.single.$2['kind'], 'answer');
        expect(sends.single.$2['text'], input);
        expect(sends.single.$2['replyTo'], 'question');
        expect(sends.single.$2.containsKey('treatment'), false);
        expect(
          api.requests.map((request) => request.$1),
          everyElement(isNot(anyOf(contains('Treatment'), contains('Consum')))),
        );
        expect(await db.outbox(scope), isEmpty);
      });
    }

    test('a signed rejection never permits a second operation ID', () async {
      final (db, api, worker, payload) = await received();
      // The first request may be held elsewhere and commit after this
      // rejection, so the rejection proves nothing about the ticket.
      api.sendRejection = const CallableFailure(
        'rejected',
        rejectionCode: 'not-found',
      );
      expect(await worker.reply(payload, 'Mam'), true);
      final operation = (await db.outbox(scope)).single;
      expect(operation.read<String>('error'), 'not-found');
      final reservations = api.requests
          .where((request) => request.$1 == 'reserveFamilyChatOperations')
          .length;
      api.sendRejection = null;
      expect(await worker.reply(payload, 'Kupię'), false);
      expect(api.sent, isEmpty);
      expect(
        api.requests
            .where((request) => request.$1 == 'reserveFamilyChatOperations')
            .length,
        reservations,
      );
      expect((await db.outbox(scope)).map((row) => row.read<String>('id')), [
        operation.read<String>('id'),
      ]);
    });

    test('a known unsent failure permits a conscious new answer', () async {
      final (db, api, worker, payload) = await received();
      final key = 'notificationReply:$scope:question';
      await db.enqueueUnsentReply(
        scope,
        'unsent_old',
        'mom',
        {
          'kind': 'answer',
          'text': 'Mam',
          'answers': <String>[],
          'replyTo': 'question',
        },
        1000,
        key,
      );
      await db.failOperation(scope, 'unsent_old', 'expired');
      await db.setMetadata(key, {
        'id': 'unsent_old',
        'digest': 'old',
        'expiresAt': 10000,
      });
      expect(await worker.reply(payload, 'Kupię'), true);
      expect(api.sent.values.single['text'], 'Kupię');
      // The failed, never-sent row stays visible and was not rebased.
      final rows = await db.outbox(scope);
      expect(rows.map((row) => row.read<String>('id')), ['unsent_old']);
      expect(rows.single.read<String>('error'), 'expired');
    });

    test('an ambiguous reply never creates or rebases an operation', () async {
      final (db, api, worker, payload) = await received();
      api.sendRejection = const CallableFailure(
        'rejected',
        rejectionCode: 'failed-precondition',
        rejectionReason: 'chat-send-outcome-unknown',
      );
      expect(await worker.reply(payload, 'Mam'), true);
      final operation = (await db.outbox(scope)).single;
      expect(operation.read<String>('error'), 'send-outcome-unknown');
      api.sendRejection = null;
      expect(await worker.reply(payload, 'Kupię'), false);
      expect(api.sent, isEmpty);
      expect((await db.outbox(scope)).map((row) => row.read<String>('id')), [
        operation.read<String>('id'),
      ]);
    });
  });
}
