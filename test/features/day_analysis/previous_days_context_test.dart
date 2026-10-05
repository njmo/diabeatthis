import 'package:diabeatthis/core/drift/database_impl.dart'
    hide AcceptedDaySummary;
import 'package:diabeatthis/features/day_analysis/data/repositories/day_summary_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_history.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_meal_batch.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/previous_days_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/serialization/day_analysis_dml_serializer.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_analysis_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/load_day_analysis_history_use_case.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/load_previous_days_context_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'day_dml_test.dart' show dmlFixture, dmlSection;

AcceptedDaySummary summary(String key, {double coverage = 100}) {
  final fixture = dmlFixture(basalCoverage: coverage);
  return AcceptedDaySummary(
    acceptedAt: fixture.acceptedAt,
    snapshot: DaySummarySnapshot.fromJson({
      ...fixture.snapshot.toJson(),
      'day': key,
    }),
  );
}

LoadDayAnalysisHistoryUseCase historyLoader(
  Future<PreviousDaysContext> Function(String) previous,
) => LoadDayAnalysisHistoryUseCase(
  now: () => DateTime.utc(2026, 10, 26, 10),
  loadGlucose: (s, e) async => [],
  loadStatuses: (s, e) async => [],
  loadTreatments: (s, e) async => [],
  loadMeals: (s, e) async => DayAnalysisMealBatch(meals: [], failedIds: {}),
  loadLows: (s, e) async => [],
  loadActivities: (s, e) async => [],
  loadPreviousDays: previous,
);

void main() {
  test(
    'archive failure does not discard successfully loaded event sources',
    () async {
      final accepted = dmlFixture();
      final history = await historyLoader(
        (_) async => throw StateError('Unavailable'),
      )(accepted);
      expect(history.previousDays, isNull);
      expect(history.glucose, isEmpty);
      expect(history.failures, {'previous_days'});
      final doc = serializeDayAnalysisContext(
        await const BuildDayAnalysisContextUseCase()(accepted, history),
      );
      expect(dmlSection(doc.text, 'PREVIOUS_DAYS')['days'], isNull);
      expect(
        dmlSection(doc.text, 'QUALITY')['unavailable_context'],
        contains('previous_day'),
      );
    },
  );

  test(
    'an empty archive is available but does not imply zero-valued previous days',
    () async {
      final accepted = dmlFixture();
      final history = await historyLoader(
        (key) => LoadPreviousDaysContextUseCase(
          loadAccepted: (s, e) async => [],
        )(key),
      )(accepted);
      expect(history.failures, isEmpty);
      final doc = serializeDayAnalysisContext(
        await const BuildDayAnalysisContextUseCase()(accepted, history),
      );
      expect(dmlSection(doc.text, 'PREVIOUS_DAYS')['days'], isEmpty);
      expect(
        dmlSection(doc.text, 'QUALITY')['unavailable_context'],
        contains('previous_day'),
      );
    },
  );

  test(
    'one archive query selects seven calendar days, excluding current and future days',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DaySummaryRepository(db);
      // Crosses the autumn DST transition; missing days remain missing.
      for (final key in [
        '2026-10-18',
        '2026-10-19',
        '2026-10-25',
        '2026-10-26',
      ]) {
        await repo.insert(summary(key));
      }
      var reads = 0;
      final context = await LoadPreviousDaysContextUseCase(
        loadAccepted: (s, e) {
          reads++;
          return repo.getBetween(s, e);
        },
      )('2026-10-26');
      expect(reads, 1);
      expect(context.startDayKey, '2026-10-19');
      expect(context.endDayKeyExclusive, '2026-10-26');
      expect(context.summaries.map((s) => s.snapshot.dayKey), [
        '2026-10-19',
        '2026-10-25',
      ]);
      expect(await repo.get('2026-10-26'), isNotNull);
    },
  );

  test(
    'previous day facts preserve unknown basal and do not rewrite accepted summaries',
    () async {
      final accepted = dmlFixture();
      final previous = summary('2026-10-24', coverage: 0);
      final original = previous.snapshot.encode();
      final history = DayAnalysisHistory(
        start: DateTime.utc(2026, 10, 23),
        end: DateTime.utc(2026, 10, 26),
        builtAt: DateTime.utc(2026, 10, 26),
        glucose: [],
        statuses: [],
        treatments: [],
        meals: [],
        lows: [],
        activities: [],
        failures: {},
        previousDays: PreviousDaysContext(
          startDayKey: '2026-10-18',
          endDayKeyExclusive: '2026-10-25',
          summaries: [previous],
        ),
      );
      final document = serializeDayAnalysisContext(
        await const BuildDayAnalysisContextUseCase()(accepted, history),
      );
      final days = dmlSection(document.text, 'PREVIOUS_DAYS')['days'] as List;
      expect(days.single['date'], '2026-10-24');
      expect(days.single['metrics']['totalInsulinUnits'], isNull);
      expect(days.single['metrics']['bolusUnits'], 6);
      expect(
        dmlSection(document.text, 'QUALITY')['unavailable_context'],
        isNot(contains('previous_day')),
      );
      expect(document.evidenceIds, contains('previous_days'));
      expect(previous.snapshot.encode(), original);
    },
  );
}
