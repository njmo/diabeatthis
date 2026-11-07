import 'package:diabeatthis/common/family_sync/enable_initial_family_sharing.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'setup enables child mirror idempotently and requests foreground synchronization',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final enable = EnableInitialFamilySharing(db, () async => 'child');
      await enable();
      final first = await db
          .customSelect('SELECT * FROM family_sync_identity')
          .getSingle();
      expect(first.read<int>('enabled'), 1);
      expect(first.read<String>('owner_uid'), 'child');
      final revision = first.read<int>('enabled_revision');
      await enable();
      final second = await db
          .customSelect('SELECT * FROM family_sync_identity')
          .getSingle();
      expect(second.read<int>('enabled_revision'), revision);
      expect(second.read<String>('source_id'), first.read<String>('source_id'));
      expect(
        (await db
                .customSelect('SELECT requested FROM family_sync_runtime')
                .getSingle())
            .read<int>('requested'),
        1,
      );
    },
  );
  for (final situation in ['signed-out', 'changed', 'other-owner']) {
    test(
      'activation rejects $situation without changing consent or owner',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        if (situation == 'other-owner') {
          await db.customStatement(
            "UPDATE family_sync_identity SET owner_uid='original'",
          );
        }
        var reads = 0;
        final enable = EnableInitialFamilySharing(db, () async {
          reads++;
          return situation == 'signed-out'
              ? null
              : situation == 'changed' && reads > 1
              ? 'other'
              : 'child';
        });
        await expectLater(enable(), throwsStateError);
        final row = await db
            .customSelect('SELECT * FROM family_sync_identity')
            .getSingle();
        expect(row.read<int>('enabled'), 0);
        expect(
          row.readNullable<String>('owner_uid'),
          situation == 'other-owner' ? 'original' : null,
        );
      },
    );
  }
}
