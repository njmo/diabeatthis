import 'package:diabeatthis/common/family_sync/family_mirror_background_runtime.dart';
import 'package:diabeatthis/common/family_sync/family_mirror_status.dart';
import 'package:diabeatthis/common/family_sync/family_plan_background_runtime.dart';
import 'package:diabeatthis/common/family_sync/presentation/child_family_cloud_ribbon.dart';
import 'package:diabeatthis/common/family_sync/record_family_cloud_connection.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'disconnecting the bound receiver clears its persisted connected presentation',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await FamilyMirrorOutbox(db).bindOwner('child');
      await db.customStatement('UPDATE family_sync_identity SET enabled=1');
      await recordFamilyCloudConnection(db, 'child', true);
      final mirror = FamilyMirrorBackgroundRuntime(db);
      addTearDown(mirror.dispose);
      final receiver = FamilyPlanBackgroundRuntime(db, mirror);
      addTearDown(receiver.dispose);
      await receiver.disconnectSignals('child');
      expect(
        (await readChildFamilyCloudState(db)).status,
        FamilyMirrorStatus.failed,
      );
    },
  );
}
