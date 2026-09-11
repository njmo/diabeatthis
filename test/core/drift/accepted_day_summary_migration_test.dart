import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_summary_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart'
    as domain;
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'v27 migration preserves history; accepted summary survives restart and cannot be overwritten',
    () async {
      final dir = await Directory.systemTemp.createTemp('day-summary-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/test.sqlite');
      var db = DatabaseImpl(NativeDatabase(file));
      final mealId = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Existing', plannedAt: 1000));
      await db.customStatement('DROP TABLE accepted_day_summary');
      await db.customStatement('PRAGMA user_version = 27');
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      final snapshot = DaySummarySnapshot(
        dayKey: '2026-09-10',
        asOf: DateTime(2026, 9, 11),
        builtAt: DateTime(2026, 9, 11, 8),
        utcOffsetMinutes: 120,
        metrics: {DaySummaryMetric.glucoseMean: 120},
        limitations: ['basal'],
        review: [],
      );
      final accepted = domain.AcceptedDaySummary(
        acceptedAt: DateTime(2026, 9, 11, 8),
        snapshot: snapshot,
      );
      final repo = DaySummaryRepository(db);
      expect((await db.mealDao.getMealById(mealId))!.name, 'Existing');
      final attempts = await Future.wait([
        for (var i = 0; i < 2; i++)
          repo.insert(accepted).then((_) => true, onError: (_) => false),
      ]);
      expect(attempts.where((success) => success), hasLength(1));
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final reopened = DaySummaryRepository(db);
      final stored = await reopened.get(snapshot.dayKey);
      expect(stored!.snapshot.encode(), snapshot.encode());
      expect(stored.acceptedAt, accepted.acceptedAt);
      await expectLater(reopened.insert(accepted), throwsA(anything));
      expect(
        (await reopened.get(snapshot.dayKey))!.snapshot.encode(),
        snapshot.encode(),
      );
    },
  );
}
