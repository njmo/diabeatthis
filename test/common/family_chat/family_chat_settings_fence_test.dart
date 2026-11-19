import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_guard_fence.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

void main() {
  for (final sqlite in [false, true]) {
    test(
      'synthetic OFF creation never adopts an existing token: sqlite=$sqlite',
      () async {
        final fence = sqlite
            ? SqliteChatGuardFence(NativeDatabase.memory())
            : MemoryChatGuardFence();
        addTearDown(fence.close);
        final first = await fence.ensureAccountRevocation('child');
        expect(first.created, true);
        expect(await fence.ensureAccountRevocation('child'), (
          token: first.token,
          created: false,
        ));
        final newer = await fence.revokeAccount('child');
        expect(await fence.ensureAccountRevocation('child'), (
          token: newer,
          created: false,
        ));
      },
    );
    test(
      'OFF latch blocks activation until the same token is acknowledged: sqlite=$sqlite',
      () async {
        final fence = sqlite
            ? SqliteChatGuardFence(NativeDatabase.memory())
            : MemoryChatGuardFence();
        addTearDown(fence.close);
        final firstVersion = (await fence.read())['version'] as String;
        expect(
          await fence.activate(firstVersion, 'child', 'scope', 'old'),
          true,
        );
        final first = await fence.revokeAccount('child');
        final blocked = await fence.read();
        expect(blocked['enabled'], false);
        expect(
          await fence.activate(
            blocked['version'] as String,
            'child',
            'scope',
            'bad',
          ),
          false,
        );
        final newer = await fence.revokeAccount('child');
        expect(await fence.clearAccountRevocation('child', first), false);
        expect(await fence.accountRevocation('child'), newer);
        expect(await fence.clearAccountRevocation('child', newer), true);
        expect(
          await fence.activate(
            blocked['version'] as String,
            'child',
            'scope',
            'late',
          ),
          false,
        );
        expect(
          await fence.activate(
            (await fence.read())['version'] as String,
            'child',
            'scope',
            'fresh',
          ),
          true,
        );
        expect(jsonEncode(await fence.read()), isNot(contains(newer)));
      },
    );
    test(
      'stale account close cannot block another active UID: sqlite=$sqlite',
      () async {
        final fence = sqlite
            ? SqliteChatGuardFence(NativeDatabase.memory())
            : MemoryChatGuardFence();
        addTearDown(fence.close);
        await fence.activate(
          (await fence.read())['version'] as String,
          'child',
          'old',
          'old',
        );
        final expected = await fence.read();
        await fence.block();
        await fence.activate(
          (await fence.read())['version'] as String,
          'other',
          'new',
          'new',
        );
        expect(await fence.block(expected: expected), isNull);
        await fence.revokeAccount('child');
        expect((await fence.read())['uid'], 'other');
        expect((await fence.read())['enabled'], true);
      },
    );
  }

  test(
    'a held OPEN cannot override OFF across two real SQLite connections',
    () async {
      final dir = await Directory.systemTemp.createTemp('chat-settings-fence-');
      final path = '${dir.path}/guard.sqlite';
      final a = SqliteChatGuardFence(NativeDatabase(File(path)));
      final b = SqliteChatGuardFence(NativeDatabase(File(path)));
      final entered = Completer<void>(), release = Completer<void>();
      try {
        Future<bool> open() async {
          final version = (await a.read())['version'] as String;
          entered.complete();
          await release.future;
          return a.activate(version, 'child', 'scope', 'late');
        }

        final pending = open();
        await entered.future;
        final token = await b.revokeAccount('child');
        release.complete();
        expect(await pending, false);
        expect((await a.read())['enabled'], false);
        expect(await a.accountRevocation('child'), token);
        expect(
          await a.activate(
            (await a.read())['version'] as String,
            'child',
            'scope',
            'new',
          ),
          false,
        );
      } finally {
        await a.close();
        await b.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'OFF survives restart and cannot wait on the settings database writer',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'chat-settings-writer-',
      );
      final path = '${dir.path}/guard.sqlite';
      var fence = SqliteChatGuardFence(NativeDatabase(File(path)));
      final chat = FamilyChatDatabase(
        NativeDatabase(File('${dir.path}/chat.sqlite')),
        fence,
      );
      final independent = SqliteChatGuardFence(NativeDatabase(File(path)));
      final entered = Completer<void>(), release = Completer<void>();
      Future<void>? writer;
      try {
        await chat.activateChat('child', 'scope', 'stamp');
        writer = chat.transaction(() async {
          await chat.setMetadata('blocked-settings-write', {});
          entered.complete();
          await release.future;
        });
        await entered.future;
        final token = await independent
            .revokeAccount('child')
            .timeout(const Duration(seconds: 2));
        expect((await independent.read())['enabled'], false);
        release.complete();
        await writer;
        await chat.close();
        fence = SqliteChatGuardFence(NativeDatabase(File(path)));
        expect(await fence.accountRevocation('child'), token);
        expect(
          await fence.activate(
            (await fence.read())['version'] as String,
            'child',
            'scope',
            'restart',
          ),
          false,
        );
        await fence.close();
      } finally {
        if (!release.isCompleted) release.complete();
        await writer;
        await independent.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'schema-two migration preserves existing guard and installation identity',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'chat-settings-migrate-',
      );
      final path = '${dir.path}/guard.sqlite';
      var fence = SqliteChatGuardFence(NativeDatabase(File(path)));
      try {
        await fence.activate(
          (await fence.read())['version'] as String,
          'child',
          'scope',
          'stamp',
        );
        final registration = await fence.nextRegistration();
        await fence.close();
        final raw = sqlite3.open(path);
        raw.execute('DROP TABLE chat_settings_revocations');
        raw.execute('PRAGMA user_version=2');
        raw.dispose();
        fence = SqliteChatGuardFence(NativeDatabase(File(path)));
        expect((await fence.read())['stamp'], 'stamp');
        final next = await fence.nextRegistration();
        expect(next['installationId'], registration['installationId']);
        expect(next['counter'], (registration['counter'] as int) + 1);
        expect(await fence.accountRevocation('child'), isNull);
      } finally {
        await fence.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
