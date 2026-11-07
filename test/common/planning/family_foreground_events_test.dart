import 'package:diabeatthis/common/family_sync/family_mirror_background_runtime.dart';
import 'package:diabeatthis/common/family_sync/family_plan_background_runtime.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class ObservedMirrorRuntime extends FamilyMirrorBackgroundRuntime {
  ObservedMirrorRuntime(super.db);
  int calls = 0;
  @override
  Future<void> tick() async {
    calls++;
  }
}

class ObservedPlanRuntime extends FamilyPlanBackgroundRuntime {
  ObservedPlanRuntime(super.db, super.mirror);
  int calls = 0;
  @override
  Future<void> tick() async {
    calls++;
  }
}

void main() {
  test(
    'local writes wake foreground publishing immediately without a poll timer',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      final runtime = ObservedMirrorRuntime(db);
      addTearDown(runtime.dispose);
      runtime.start();
      expect(runtime.timer, isNull);
      final before = runtime.calls;
      await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Walk',
              percentagePre: 20,
              percentagePost: 30,
            ),
          );
      await Future<void>.delayed(Duration.zero);
      expect(runtime.calls, greaterThan(before));
    },
  );
  test('foreground receiver starts without periodic network polling', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final mirror = ObservedMirrorRuntime(db);
    addTearDown(mirror.dispose);
    final runtime = ObservedPlanRuntime(db, mirror);
    addTearDown(runtime.dispose);
    runtime.start();
    expect(runtime.calls, 1);
    expect(runtime.timer, isNull);
  });
}
