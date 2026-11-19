import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart' show SqliteException;

String _nonce() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

/// Independent admission control. Its transactions never wait for native UI.
abstract interface class FamilyChatGuardFence {
  Future<Map<String, dynamic>> read();
  Future<String?> block({
    String? expectedStamp,
    Map<String, dynamic>? expected,
  });
  Future<String> revokeAccount(String uid);
  Future<({String token, bool created})> ensureAccountRevocation(String uid);
  Future<String?> accountRevocation(String uid);
  Future<bool> clearAccountRevocation(String uid, String token);
  Future<bool> activate(String version, String uid, String scope, String stamp);
  Future<Map<String, dynamic>> nextRegistration();
  Future<void> close();
}

extension ChatFenceState on FamilyChatGuardFence {
  Future<bool> blocked() async => (await read())['enabled'] != true;
}

class MemoryChatGuardFence implements FamilyChatGuardFence {
  final _revocations = <String, String>{};
  final _installation = base64Url
      .encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))
      .replaceAll('=', '');
  int _counter = 0;
  @override
  Future<Map<String, dynamic>> nextRegistration() async => {
    'installationId': _installation,
    'counter': ++_counter,
  };
  Map<String, dynamic> _state = {'enabled': false, 'version': _nonce()};
  @override
  Future<Map<String, dynamic>> read() async => Map.of(_state);
  @override
  Future<String?> block({
    String? expectedStamp,
    Map<String, dynamic>? expected,
  }) async {
    if (expectedStamp != null && _state['stamp'] != expectedStamp) return null;
    if (expected != null &&
        ![
          'enabled',
          'version',
          'uid',
          'scope',
          'stamp',
        ].every((key) => expected[key] == _state[key])) {
      return null;
    }
    final version = _nonce();
    _state = {'enabled': false, 'version': version};
    return version;
  }

  @override
  Future<String> revokeAccount(String uid) async {
    final token = _nonce();
    _revocations[uid] = token;
    if (_state['uid'] == null || _state['uid'] == uid) await block();
    return token;
  }

  @override
  Future<({String token, bool created})> ensureAccountRevocation(
    String uid,
  ) async {
    final existing = _revocations[uid];
    if (existing != null) return (token: existing, created: false);
    return (token: await revokeAccount(uid), created: true);
  }

  @override
  Future<String?> accountRevocation(String uid) async => _revocations[uid];
  @override
  Future<bool> clearAccountRevocation(String uid, String token) async {
    if (_revocations[uid] != token) return false;
    _revocations.remove(uid);
    return true;
  }

  @override
  Future<bool> activate(
    String version,
    String uid,
    String scope,
    String stamp,
  ) async {
    if (_state['version'] != version || _revocations.containsKey(uid)) {
      return false;
    }
    _state = {
      'version': version,
      'uid': uid,
      'scope': scope,
      'stamp': stamp,
      'enabled': true,
    };
    return true;
  }

  @override
  Future<void> close() async {}
}

/// Separate SQLite admission control cannot be held by native presentation.
class SqliteChatGuardFence extends GeneratedDatabase
    implements FamilyChatGuardFence {
  SqliteChatGuardFence([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'family_chat_guard',
              native: const DriftNativeOptions(
                databaseDirectory: getApplicationSupportDirectory,
              ),
            ),
      );
  @override
  int get schemaVersion => 3;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE chat_guard (id INTEGER PRIMARY KEY CHECK(id=1),payload TEXT NOT NULL)',
      );
      await customStatement('INSERT INTO chat_guard VALUES (1,?)', [
        jsonEncode({'enabled': false, 'version': _nonce()}),
      ]);
      await _installRegistration();
      await _installRevocations();
    },
    onUpgrade: (_, from, to) async {
      if (from < 2) await _installRegistration();
      if (from < 3) await _installRevocations();
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA busy_timeout=5000');
      await customStatement('PRAGMA journal_mode=WAL');
    },
  );
  Future<void> _installRevocations() => customStatement(
    'CREATE TABLE chat_settings_revocations (uid TEXT PRIMARY KEY,token TEXT NOT NULL)',
  );
  Future<void> _installRegistration() async {
    await customStatement(
      'CREATE TABLE chat_registration (id INTEGER PRIMARY KEY CHECK(id=1),installation TEXT NOT NULL,counter INTEGER NOT NULL)',
    );
    final installation = base64Url
        .encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
    await customStatement('INSERT INTO chat_registration VALUES (1,?,0)', [
      installation,
    ]);
  }

  @override
  Future<Map<String, dynamic>> nextRegistration() => _write(() async {
    final row = await customSelect(
      'SELECT installation,counter FROM chat_registration WHERE id=1',
    ).getSingle();
    final counter = row.read<int>('counter') + 1;
    await customStatement('UPDATE chat_registration SET counter=? WHERE id=1', [
      counter,
    ]);
    return {
      'installationId': row.read<String>('installation'),
      'counter': counter,
    };
  });
  @override
  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.from(
    jsonDecode(
          (await customSelect(
            'SELECT payload FROM chat_guard WHERE id=1',
          ).getSingle()).read<String>('payload'),
        )
        as Map,
  );
  Future<T> _write<T>(Future<T> Function() operation) async {
    while (true) {
      try {
        return await transaction(() async {
          await customStatement(
            'UPDATE chat_guard SET payload=payload WHERE id=1',
          );
          return operation();
        });
      } catch (error) {
        final cause = error is DriftRemoteException ? error.remoteCause : error;
        if (cause is! SqliteException ||
            (cause.resultCode != 5 && cause.resultCode != 6)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  @override
  Future<String?> block({
    String? expectedStamp,
    Map<String, dynamic>? expected,
  }) => _write(() async {
    final current = await read();
    if (expectedStamp != null && current['stamp'] != expectedStamp) return null;
    if (expected != null &&
        ![
          'enabled',
          'version',
          'uid',
          'scope',
          'stamp',
        ].every((key) => expected[key] == current[key])) {
      return null;
    }
    final version = _nonce();
    await customStatement('UPDATE chat_guard SET payload=? WHERE id=1', [
      jsonEncode({'enabled': false, 'version': version}),
    ]);
    return version;
  });
  @override
  Future<String> revokeAccount(String uid) => _write(() async {
    final token = _nonce();
    await customStatement(
      'INSERT OR REPLACE INTO chat_settings_revocations(uid,token) VALUES(?,?)',
      [uid, token],
    );
    final current = await read();
    if (current['uid'] == null || current['uid'] == uid) {
      await customStatement('UPDATE chat_guard SET payload=? WHERE id=1', [
        jsonEncode({'enabled': false, 'version': _nonce()}),
      ]);
    }
    return token;
  });
  @override
  Future<({String token, bool created})> ensureAccountRevocation(String uid) =>
      _write(() async {
        final existing = await accountRevocation(uid);
        if (existing != null) return (token: existing, created: false);
        final token = _nonce();
        await customStatement(
          'INSERT INTO chat_settings_revocations(uid,token) VALUES(?,?)',
          [uid, token],
        );
        final current = await read();
        if (current['uid'] == null || current['uid'] == uid) {
          await customStatement('UPDATE chat_guard SET payload=? WHERE id=1', [
            jsonEncode({'enabled': false, 'version': _nonce()}),
          ]);
        }
        return (token: token, created: true);
      });
  @override
  Future<String?> accountRevocation(String uid) async => (await customSelect(
    'SELECT token FROM chat_settings_revocations WHERE uid=?',
    variables: [Variable(uid)],
  ).getSingleOrNull())?.read<String>('token');
  @override
  Future<bool> clearAccountRevocation(String uid, String token) =>
      _write(() async {
        if (await accountRevocation(uid) != token) return false;
        await customStatement(
          'DELETE FROM chat_settings_revocations WHERE uid=? AND token=?',
          [uid, token],
        );
        return true;
      });
  @override
  Future<bool> activate(
    String version,
    String uid,
    String scope,
    String stamp,
  ) => _write(() async {
    if ((await read())['version'] != version ||
        await accountRevocation(uid) != null) {
      return false;
    }
    await customStatement('UPDATE chat_guard SET payload=? WHERE id=1', [
      jsonEncode({
        'version': version,
        'uid': uid,
        'scope': scope,
        'stamp': stamp,
        'enabled': true,
      }),
    ]);
    return true;
  });
}
