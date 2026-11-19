import 'dart:async';
import 'dart:io';

import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_guard_fence.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_notification_platform.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _HeldFence implements FamilyChatGuardFence {
  _HeldFence(this.delegate);
  final FamilyChatGuardFence delegate;
  @override
  Future<Map<String, dynamic>> nextRegistration() =>
      delegate.nextRegistration();
  bool hold = false;
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<Map<String, dynamic>> read() => delegate.read();
  @override
  Future<String?> block({
    String? expectedStamp,
    Map<String, dynamic>? expected,
  }) => delegate.block(expectedStamp: expectedStamp, expected: expected);
  @override
  Future<String> revokeAccount(String uid) => delegate.revokeAccount(uid);
  @override
  Future<({String token, bool created})> ensureAccountRevocation(String uid) =>
      delegate.ensureAccountRevocation(uid);
  @override
  Future<String?> accountRevocation(String uid) =>
      delegate.accountRevocation(uid);
  @override
  Future<bool> clearAccountRevocation(String uid, String token) =>
      delegate.clearAccountRevocation(uid, token);
  @override
  Future<bool> activate(
    String version,
    String uid,
    String scope,
    String stamp,
  ) async {
    if (hold) {
      entered.complete();
      await release.future;
    }
    return delegate.activate(version, uid, scope, stamp);
  }

  @override
  Future<void> close() => delegate.close();
}

void main() {
  const expected = {'uid': 'child', 'scope': 'family-epoch', 'stamp': 'first'};
  test(
    'an activation cannot erase a newer cross-connection revocation generation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chat-activation-race-',
      );
      final file = File('${directory.path}/chat.sqlite');
      FamilyChatGuardFence fence() => SqliteChatGuardFence(
        NativeDatabase.createInBackground(
          File('${directory.path}/guard.sqlite'),
        ),
      );
      final held = _HeldFence(fence());
      final main = FamilyChatDatabase(
        NativeDatabase.createInBackground(file),
        held,
      );
      final background = FamilyChatDatabase(
        NativeDatabase.createInBackground(file),
        fence(),
      );
      try {
        await main.activateChat('child', 'family-epoch', 'first');
        final version = (await held.read())['version'] as String;
        held.hold = true;
        final activating = main.activateChat(
          'child',
          'family-epoch',
          'second',
          expectedGeneration: version,
        );
        await held.entered.future;
        final blocked = Completer<void>();
        final revoke = background.deactivateChat(
          onBlocked: (_) => blocked.complete(),
        );
        await blocked.future;
        expect(
          await background.withChatGuard(expected, () async => true),
          isNull,
        );
        held.release.complete();
        await Future.wait([activating, revoke]);
        expect((await main.activeChat())['enabled'], false);
      } finally {
        await background.close();
        await main.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'a committed pending intent can replay safely after restart before native display',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chat-pending-display-',
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
      const notice = (id: 42, tag: 'family-chat:pending');
      var db = open();
      var displays = 0;
      try {
        await db.activateChat('child', 'family-epoch', 'first');
        expect(await db.prepareNotification(expected, notice), true);
        await db.close();
        db = open();
        Future<void> show() async {
          displays++;
        }

        expect(
          await db.presentNotification(
            expected,
            notice,
            show: show,
            cancel: () async {},
          ),
          true,
        );
        expect(
          await db.presentNotification(
            expected,
            notice,
            show: show,
            cancel: () async {},
          ),
          false,
        );
        expect(displays, 1);
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'missing, disabled, different UID and obsolete stamps cannot perform background work',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var performed = 0;
      Future<int> action() async => ++performed;
      expect(await db.withChatGuard(expected, action), isNull);
      await db.activateChat('child', 'family-epoch', 'first');
      expect(await db.withChatGuard(expected, action), 1);
      await db.deactivateChat();
      expect(await db.withChatGuard(expected, action), isNull);
      await db.activateChat('parent', 'other-epoch', 'second');
      expect(await db.withChatGuard(expected, action), isNull);
      await db.activateChat('child', 'family-epoch', 'third');
      expect(await db.withChatGuard(expected, action), isNull);
      await db.deactivateChat(expectedStamp: 'first');
      expect((await db.activeChat())['stamp'], 'third');
      expect(performed, 1);
    },
  );
  test(
    'a stale activation cannot reopen authorization after the initiating state changed',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.activateChat(
        'child',
        'family-epoch',
        'old',
        allowed: () => false,
      );
      expect((await db.activeChat())['enabled'], false);
    },
  );
  test(
    'two real SQLite connections order display before revoke cancellation and reject a late old worker',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'family-chat-guard-',
      );
      final file = File('${directory.path}/chat.sqlite');
      final main = FamilyChatDatabase(
        NativeDatabase.createInBackground(file),
        SqliteChatGuardFence(
          NativeDatabase.createInBackground(
            File('${directory.path}/guard.sqlite'),
          ),
        ),
      );
      final background = FamilyChatDatabase(
        NativeDatabase.createInBackground(file),
        SqliteChatGuardFence(
          NativeDatabase.createInBackground(
            File('${directory.path}/guard.sqlite'),
          ),
        ),
      );
      try {
        await main.activateChat('child', 'family-epoch', 'first');
        final entered = Completer<void>(), release = Completer<void>();
        final order = <String>[];
        await background.prepareNotification(expected, (
          id: 42,
          tag: 'chat-test',
        ));
        final showing = background.withChatGuard(expected, () async {
          entered.complete();
          await release.future;
          order.add('shown');
          return true;
        });
        await entered.future;
        final revoke = main.deactivateChat().then((ids) {
          expect(ids, [(id: 42, tag: 'chat-test')]);
          order.add('cancel');
        });
        await Future<void>.delayed(const Duration(milliseconds: 5300));
        expect(await background.fence.blocked(), true);
        expect(
          await background.withChatGuard(expected, () async => true),
          isNull,
        );
        expect(order, isEmpty);
        release.complete();
        await Future.wait([showing, revoke]);
        expect(order, ['shown', 'cancel']);
        expect(
          await background.withChatGuard(expected, () async => true),
          isNull,
        );
      } finally {
        await background.close();
        await main.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'a display crash and failed cancellation keep a durable cleanup record across reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chat-cancel-recovery-',
      );
      final file = File('${directory.path}/chat.sqlite');
      FamilyChatDatabase open() => FamilyChatDatabase(
        NativeDatabase.createInBackground(file),
        SqliteChatGuardFence(
          NativeDatabase.createInBackground(
            File('${directory.path}/guard.sqlite'),
          ),
        ),
      );
      const notice = (id: 42, tag: 'family-chat:test');
      final visible = <String>{};
      var db = open();
      try {
        await db.activateChat('child', 'family-epoch', 'first');
        await expectLater(
          db.presentNotification(
            expected,
            notice,
            show: () async {
              visible.add(notice.tag);
              throw StateError('crash after OS display');
            },
            cancel: () async {
              visible.remove(notice.tag);
            },
          ),
          throwsStateError,
        );
        await db.close();
        db = open();
        var pending = await db.deactivateChat();
        expect(pending, [notice]);
        await db.clearScope('family-epoch');
        expect(await db.cancellationIntents(), [notice]);
        await FamilyChatNotificationPlatform.cancel(
          db,
          pending,
          keepTrying: () => false,
          operation: (_) async {
            throw StateError('OS temporarily unavailable');
          },
        );
        expect(visible, contains(notice.tag));
        await db.close();
        db = open();
        pending = await db.deactivateChat();
        expect(pending, [notice]);
        await FamilyChatNotificationPlatform.cancel(
          db,
          pending,
          operation: (_) async {
            visible.remove(notice.tag);
          },
        );
        expect(visible, isEmpty);
        expect(
          await db.notificationShown(
            'family-epoch',
            notice.id,
            tag: notice.tag,
          ),
          false,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
