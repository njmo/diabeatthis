import '../../core/drift/database_impl.dart';

/// Independent receive-channel health cannot be cleared by an upload success.
Future<void> recordFamilyCloudConnection(
  DatabaseImpl db,
  String uid,
  bool? connected,
) async {
  try {
    await db.customStatement(
      'UPDATE family_cloud_connection SET owner_uid=?,state=?,updated_at=? WHERE singleton=1 AND EXISTS(SELECT 1 FROM family_sync_identity WHERE enabled=1 AND owner_uid=?)',
      [
        uid,
        connected == null
            ? 'connecting'
            : connected
            ? 'connected'
            : 'disconnected',
        DateTime.now().millisecondsSinceEpoch,
        uid,
      ],
    );
  } catch (_) {
    // Optional connection feedback must never interrupt local monitoring.
  }
}
