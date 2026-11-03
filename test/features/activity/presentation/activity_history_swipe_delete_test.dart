import 'dart:async';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/activity/data/providers/delete_activity_history_entry_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_list.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  for (final outcome in ['cancel', 'delete', 'failure']) {
    testWidgets('left swipe $outcome keeps history consistent', (tester) async {
      final now = DateTime(2026, 11, 3, 8);
      final entries = [
        ActivityLogSummaryData(id: 1, activityId: 7, activityName: 'Błędny wpis',
          startedAt: now, endedAt: now.add(const Duration(minutes: 45)), durationMinutes: 45),
        ActivityLogSummaryData(id: 2, activityId: 7, activityName: 'Prawidłowy wpis',
          startedAt: now.subtract(const Duration(days: 1)), endedAt: now.subtract(const Duration(hours: 23)), durationMinutes: 60),
      ];
      final changes = StreamController<List<ActivityLogSummaryData>>.broadcast();
      addTearDown(changes.close);
      final deletedIds = <int>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [
          activityLogListStreamProvider(activityId: null).overrideWith((_) async* {
            yield entries.toList();
            yield* changes.stream;
          }),
          deleteActivityHistoryEntryProvider.overrideWith((ref, id) async {
            if (outcome == 'failure') throw StateError('Test write failed');
            deletedIds.add(id);
            entries.removeWhere((entry) => entry.id == id);
            changes.add(entries.toList());
          }),
        ],
        child: localizedMaterialApp(home: const Scaffold(body: ActivityLogList())),
      ));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Błędny wpis'), const Offset(-650, 0));
      await tester.pumpAndSettle();
      expect(find.text('Usunąć wpis aktywności?'), findsOneWidget);
      expect(deletedIds, isEmpty);
      await tester.tap(find.text(outcome == 'cancel' ? 'Anuluj' : 'Usuń'));
      await tester.pumpAndSettle();
      expect(find.text('Prawidłowy wpis'), findsOneWidget);
      expect(find.text('Błędny wpis'), outcome == 'delete' ? findsNothing : findsOneWidget);
      expect(deletedIds, outcome == 'delete' ? [1] : isEmpty);
      if (outcome == 'failure') {
        expect(find.text('Nie udało się usunąć wpisu aktywności. Spróbuj ponownie.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  test('deleting one entry preserves its activity definition and other logs', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final activityId = await db.into(db.activity).insert(ActivityCompanion.insert(
      name: 'WF', percentagePre: 80, percentagePost: 100,
    ));
    final first = await db.into(db.activityLog).insert(ActivityLogCompanion.insert(
      activityId: activityId, startedAt: 1000, endedAt: const drift.Value(2000),
    ));
    final second = await db.into(db.activityLog).insert(ActivityLogCompanion.insert(
      activityId: activityId, startedAt: 3000,
    ));
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    await container.read(deleteActivityHistoryEntryProvider(first).future);
    expect(await db.activityDao.getActivityLogByIdOrNull(first), isNull);
    expect(await db.activityDao.getActivityLogByIdOrNull(second), isNotNull);
    expect((await db.activityDao.getActivityById(activityId)).name, 'WF');
  });
}
