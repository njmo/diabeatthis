import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pending activity provider returns null when there is no active log',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);

      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final pendingActivity = await container.read(
        getPendingActivityProvider.future,
      );

      expect(pendingActivity, isNull);
    },
  );
}
