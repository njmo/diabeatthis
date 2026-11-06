import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/drift/database_impl.dart';

const familyMirrorSyncRequest = 'family-mirror-sync';

/// Persist first; an unavailable worker or platform channel cannot lose work.
Future<void> requestFamilyMirrorSync(DatabaseImpl db) async {
  await db.customStatement(
    'UPDATE family_sync_runtime SET requested=1 WHERE singleton=1',
  );
  try {
    // Android's handler does not return a result. Never await it on the import
    // path; bound its lifetime and consume asynchronous platform failures.
    unawaited(
      const MethodChannel('flutter_foreground_task/methods')
          .invokeMethod<void>('sendData', familyMirrorSyncRequest)
          .timeout(const Duration(seconds: 1))
          .catchError((Object error) {}),
    );
  } catch (_) {
    // The periodic worker consumes the durable request after recovery.
  }
}
