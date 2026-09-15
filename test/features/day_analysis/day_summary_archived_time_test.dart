import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_summary_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart'
    as domain;
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_review_form.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  // A day crossing Poland's autumn DST transition. UTC data ensures rendering
  // cannot accidentally pass by relying on the host's local timezone.
  final start = DateTime.utc(2026, 10, 24, 20);
  final end = DateTime.utc(2026, 10, 25, 5);
  final asOf = DateTime.utc(2026, 10, 25, 23);
  final snapshot = DaySummarySnapshot(
    dayKey: '2026-10-25',
    asOf: asOf,
    builtAt: asOf,
    nightStart: start,
    nightEnd: end,
    utcOffsetMinutes: 120,
    displayUtcOffsets: {
      start.toIso8601String(): 120,
      end.toIso8601String(): 60,
      asOf.toIso8601String(): 60,
    },
    metrics: {},
    limitations: [],
    review: [],
  );

  testWidgets(
    'archive renders captured wall times across DST instead of current device zone',
    (tester) async {
      final decoded = DaySummarySnapshot.decode(snapshot.encode());
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DaySummaryReviewForm(snapshot: decoded),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dane do 26.10.2026 00:00'), findsOneWidget);
      expect(find.text('Noc: 24.10 22:00–25.10 06:00'), findsOneWidget);
    },
  );

  test(
    'legacy documents use their saved offset without requiring new fields',
    () {
      final json = snapshot.toJson()..remove('displayUtcOffsets');
      final legacy = DaySummarySnapshot.fromJson(json);
      expect(legacy.displayTime(start).hour, 22);
      expect(legacy.utcOffsetMinutes, 120);
    },
  );

  test(
    'acceptance timezone survives storage independently of day timezone',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DaySummaryRepository(db);
      await repo.insert(
        domain.AcceptedDaySummary(
          snapshot: snapshot,
          acceptedAt: DateTime.utc(2026, 10, 26, 7),
          utcOffsetMinutes: 60,
        ),
      );
      final stored = (await repo.get(snapshot.dayKey))!;
      expect(stored.displayAcceptedAt.hour, 8);
      expect(stored.utcOffsetMinutes, 60);
      expect(stored.snapshot.encode(), snapshot.encode());
    },
  );
}
