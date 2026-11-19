import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'family_chat_database.dart';

final familyChatDatabaseProvider = Provider<FamilyChatDatabase>((ref) {
  final db = FamilyChatDatabase();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});
