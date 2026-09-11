import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/accept_day_summary_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

DaySummarySnapshot preview({
  double mean = 120,
  bool gaps = false,
  bool pending = false,
  DateTime? asOf,
}) => DaySummarySnapshot(
  dayKey: '2026-09-10',
  asOf: asOf ?? DateTime(2026, 9, 11),
  builtAt: DateTime(2026, 9, 11, 8),
  utcOffsetMinutes: 120,
  metrics: {DaySummaryMetric.glucoseMean: mean},
  limitations: gaps ? ['glucose'] : [],
  review: pending
      ? [
          DaySummaryReviewRecord(
            kind: DaySummaryReviewKind.meal,
            occurredAt: DateTime(2026, 9, 10, 12),
            mealId: null,
            sourceId: 'wizard',
            resolution: DaySummaryResolution.unresolved,
          ),
        ]
      : [],
);

void main() {
  test(
    'only past calendar days can be finalized, including midnight boundary',
    () {
      final day = DateTime(2026, 9, 10);
      expect(
        AcceptDaySummaryUseCase.isAvailable(day, DateTime(2026, 9, 10, 23, 59)),
        isFalse,
      );
      expect(
        AcceptDaySummaryUseCase.isAvailable(day, DateTime(2026, 9, 11)),
        isTrue,
      );
      expect(
        AcceptDaySummaryUseCase.isAvailable(
          DateTime(2026, 9, 12),
          DateTime(2026, 9, 11, 8),
        ),
        isFalse,
      );
    },
  );

  test(
    'gaps and every unresolved entry require explicit acknowledgement',
    () async {
      final snapshot = preview(gaps: true, pending: true);
      final saved = <AcceptedDaySummary>[];
      final accept = AcceptDaySummaryUseCase(
        loadCurrent: () async => snapshot,
        save: (value) async => saved.add(value),
        now: () => DateTime(2026, 9, 11, 8),
      );
      await expectLater(
        accept(snapshot, skippedRecords: {}, acknowledgeLimitations: true),
        throwsStateError,
      );
      await expectLater(
        accept(snapshot, skippedRecords: {0}, acknowledgeLimitations: false),
        throwsStateError,
      );
      expect(saved, isEmpty);
      await accept(snapshot, skippedRecords: {0}, acknowledgeLimitations: true);
      expect(saved.single.snapshot.encode(), snapshot.encode());
    },
  );

  test(
    'stale preview and unfinished observation windows cannot be saved',
    () async {
      var saves = 0;
      final accept = AcceptDaySummaryUseCase(
        loadCurrent: () async => preview(mean: 130),
        save: (_) async {
          saves++;
        },
        now: () => DateTime(2026, 9, 11, 8),
      );
      await expectLater(
        accept(preview(), skippedRecords: {}, acknowledgeLimitations: true),
        throwsA(isA<StaleDaySummary>()),
      );
      await expectLater(
        accept(
          preview(asOf: DateTime(2026, 9, 10, 22)),
          skippedRecords: {},
          acknowledgeLimitations: true,
        ),
        throwsStateError,
      );
      expect(saves, 0);
    },
  );

  test('snapshot is immutable and rejects unknown schema versions', () {
    final snapshot = preview(gaps: true, pending: true);
    final copy = DaySummarySnapshot.decode(snapshot.encode());
    expect(copy.encode(), snapshot.encode());
    expect(() => copy.metrics.clear(), throwsUnsupportedError);
    expect(() => copy.review.clear(), throwsUnsupportedError);
    expect(
      () => DaySummarySnapshot.decode(
        snapshot.encode().replaceFirst('"version":1', '"version":2'),
      ),
      throwsFormatException,
    );
  });
}
