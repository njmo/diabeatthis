import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_analysis_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/meal_preview_fixture.dart';

void main() {
  final at = DateTime(2026, 11, 3, 12);
  final lang = lookupAppLocalizations(const Locale('pl'));
  TemporaryTarget target(int offset, int duration) => TemporaryTarget(nightscoutId: '$offset',
    createdAt: at.add(Duration(minutes: offset)), durationInMiliseconds: duration * 60000,
    duration: duration, targetBottom: 90, targetTop: 90);
  MealAnalysisData analysis(List<TemporaryTarget> history) => MealAnalysisData(
    chartStart: at.subtract(const Duration(minutes: 45)), chartEnd: at.add(const Duration(hours: 1)),
    expectedChartEnd: at.add(const Duration(hours: 1)), eventStart: at.subtract(const Duration(hours: 1)),
    eventEnd: at.add(const Duration(hours: 1)), mealTime: at, glucoseReadings: const [], treatments: const [],
    temporaryTargets: [history.first], temporaryTargetHistory: history, deviceStatuses: const [],
    linkedActivities: const [], linkedMeals: const [], timelineEvents: const [],
  );
  final details = mealPreviewFixture(history: [MealStatusHistoryEntryData(id: 1, mealId: 1,
    status: 'waited-eating', createdAt: at)]);

  test('the preparation band ends at eating and the target continuation does not overlap it', () {
    final ranges = mealTimelineChartRanges(analysis([target(-20, 60)]), details: details, messages: lang, eatingColor: Colors.teal);
    final preparation = ranges.singleWhere((range) => range.label == lang.mealTargetPreparation);
    final continuation = ranges.singleWhere((range) => range.label == lang.mealTargetValue(90));
    expect(preparation.start, at.subtract(const Duration(minutes: 20)));
    expect(preparation.end, at);
    expect(continuation.start, at);
    expect(continuation.end, at.add(const Duration(minutes: 40)));
  });

  test('a target cancelled outside the event window is not incorrectly drawn across the meal', () {
    final ranges = mealTimelineChartRanges(analysis([target(-120, 180), target(-70, 0)]),
      details: details, messages: lang, eatingColor: Colors.teal);
    expect(ranges, isEmpty);
  });

  test('missing recorded eating time never gets a preparation label', () {
    final ranges = mealTimelineChartRanges(analysis([target(-20, 60)]), details: mealPreviewFixture(),
      messages: lang, eatingColor: Colors.teal);
    expect(ranges.where((range) => range.label == lang.mealTargetPreparation), isEmpty);
    expect(ranges.single.start, at.subtract(const Duration(minutes: 20)));
  });
}
