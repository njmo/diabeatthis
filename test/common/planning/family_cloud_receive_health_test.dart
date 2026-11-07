import 'package:diabeatthis/common/family_sync/family_mirror_status.dart';
import 'package:diabeatthis/common/family_sync/presentation/child_family_cloud_ribbon.dart';
import 'package:diabeatthis/common/family_sync/record_family_cloud_connection.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'upload success cannot pretend a disconnected receive channel is connected',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await FamilyMirrorOutbox(db).bindOwner('child');
      await db.customStatement('UPDATE family_sync_identity SET enabled=1');
      expect(
        (await readChildFamilyCloudState(db)).status,
        FamilyMirrorStatus.syncing,
      );
      await recordFamilyCloudConnection(db, 'child', false);
      expect(
        (await readChildFamilyCloudState(db)).status,
        FamilyMirrorStatus.failed,
      );
      await db.customStatement(
        'UPDATE family_sync_identity SET last_error=NULL,last_success=?',
        [DateTime.now().millisecondsSinceEpoch],
      );
      expect(
        (await readChildFamilyCloudState(db)).status,
        FamilyMirrorStatus.failed,
      );
      await recordFamilyCloudConnection(db, 'foreign', true);
      expect(
        (await readChildFamilyCloudState(db)).status,
        FamilyMirrorStatus.failed,
      );
      await recordFamilyCloudConnection(db, 'child', true);
      expect(
        (await readChildFamilyCloudState(db)).status,
        isNot(FamilyMirrorStatus.failed),
      );
    },
  );
}
