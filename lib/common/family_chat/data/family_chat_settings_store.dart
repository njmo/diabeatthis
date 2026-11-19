import 'dart:async';

import 'family_chat_database.dart';

/// Minimal settings and mutation metadata, never message/roster contents.
/// This UID-scoped record deliberately survives clearing the chat cache/OFF.
class FamilyChatSettingsStore {
  const FamilyChatSettingsStore(this.db);
  final FamilyChatDatabase db;
  String _key(String uid) => 'chatSettings:$uid';

  Future<Map<String, dynamic>> read(String uid) async =>
      await db.metadata(_key(uid)) ?? {};

  Future<Map<String, dynamic>> update(
    String uid,
    FutureOr<void> Function(Map<String, dynamic> state) change,
  ) => db.transaction(() async {
    // Acquire the writer before reading, also across background connections.
    await db.customStatement(
      'INSERT OR IGNORE INTO chat_metadata(key,value) VALUES (?,?)',
      [_key(uid), '{}'],
    );
    final state = await read(uid);
    await change(state);
    state['_revision'] = ((state['_revision'] as int?) ?? 0) + 1;
    await db.setMetadata(_key(uid), state);
    return state;
  });
}
