import '../../core/drift/database_impl.dart';

enum FamilyMirrorStatus {
  hidden,
  syncing,
  waiting,
  failed,
  blocked,
  synchronized,
}

Future<FamilyMirrorStatus> readFamilyMirrorStatus(
  DatabaseImpl db,
  DateTime now,
) async {
  final row = await db.customSelect('''SELECT enabled,last_error,last_success,
    (SELECT active_until FROM family_sync_runtime WHERE singleton=1) AS active_until,
    (SELECT COUNT(*) FROM family_sync_outbox WHERE revision>acknowledged_revision) AS pending,
    (SELECT COUNT(*) FROM family_sync_outbox WHERE revision>acknowledged_revision AND failed_revision=revision) AS blocked
    FROM family_sync_identity WHERE singleton=1''').getSingle();
  if (row.read<int>('enabled') != 1) return FamilyMirrorStatus.hidden;
  if (row.read<int>('blocked') > 0) return FamilyMirrorStatus.blocked;
  if (row.read<int>('pending') > 0) {
    if (row.read<int>('active_until') > now.millisecondsSinceEpoch) {
      return FamilyMirrorStatus.syncing;
    }
    return row.readNullable<String>('last_error') == null
        ? FamilyMirrorStatus.waiting
        : FamilyMirrorStatus.failed;
  }
  final lastSuccess = row.readNullable<int>('last_success');
  if (lastSuccess != null && now.millisecondsSinceEpoch - lastSuccess < 5000) {
    return FamilyMirrorStatus.synchronized;
  }
  return FamilyMirrorStatus.hidden;
}
