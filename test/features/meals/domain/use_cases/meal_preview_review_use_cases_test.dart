import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/domain/models/meal_application_review.dart';
import 'package:diabeatthis/features/meals/domain/models/meal_ecarbs_proposal.dart';
import 'package:diabeatthis/features/meals/domain/models/meal_save_event.dart';
import 'package:diabeatthis/features/meals/domain/use_cases/build_meal_application_review_use_case.dart';
import 'package:diabeatthis/features/meals/domain/use_cases/build_meal_ecarbs_proposal_use_case.dart';
import 'package:diabeatthis/features/meals/domain/use_cases/build_meal_origin_use_case.dart';
import 'package:diabeatthis/features/meals/domain/use_cases/build_meal_save_timeline_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/meal_preview_fixture.dart';

void main() {
  final at = DateTime(2026, 11, 3, 12);

  test('save events use actual timestamps in chronological order without inventing a sync or plan event', () {
    final details = mealPreviewFixture(created: at, updated: at.add(const Duration(minutes: 30)),
      summarized: at.add(const Duration(minutes: 25)), planned: at.add(const Duration(days: 1)),
      decision: mealPreviewDecision(created: at.add(const Duration(minutes: 1)), updated: at.add(const Duration(minutes: 2))));
    final events = const BuildMealSaveTimelineUseCase()(details);
    expect(events.map((event) => event.kind), [MealSaveEventKind.created, MealSaveEventKind.advisorCreated,
      MealSaveEventKind.advisorUpdated, MealSaveEventKind.summarized, MealSaveEventKind.updated]);
    expect(events.any((event) => event.at == details.meal.plannedAt), isFalse);
    expect(const BuildMealSaveTimelineUseCase()(mealPreviewFixture(synced: true)).map((event) => event.kind), [MealSaveEventKind.created]);
    expect(const BuildMealSaveTimelineUseCase()(mealPreviewFixture(synced: false)).map((event) => event.kind), [MealSaveEventKind.created]);
  });

  test('origins distinguish a source meal, missing source, template and meals copied from this one', () {
    const build = BuildMealOriginUseCase();
    expect(build(mealPreviewFixture()), isNull);
    final copied = build(mealPreviewFixture(sourceId: 7, source: const MealCopySourceData(id: 7, name: 'Obiad')))!;
    expect(copied.sourceId, 7);
    expect(copied.source?.name, 'Obiad');
    expect(build(mealPreviewFixture(sourceId: 7))!.source, isNull);
    expect(build(mealPreviewFixture(templateId: 8))!.templateId, 8);
    expect(build(mealPreviewFixture(usages: [MealCopyUsageData(id: 2, name: 'Kopia', plannedAt: at, status: 'planned', sourceType: 'meal')]))!.usages.single.id, 2);
  });

  test('only known complete extended-carb schedules get a delivery bar', () {
    const build = BuildMealEcarbsProposalUseCase();
    expect(build(mealPreviewFixture()).hasDecision, isFalse);
    expect(build(mealPreviewFixture(decision: mealPreviewDecision())).hasSchedule, isTrue);
    expect(build(mealPreviewFixture(decision: mealPreviewDecision(mode: 'extraBolus'))).kind, MealEcarbsProposalKind.extraBolus);
    expect(build(mealPreviewFixture(decision: mealPreviewDecision(mode: 'extraBolus'))).hasSchedule, isFalse);
    expect(build(mealPreviewFixture(decision: mealPreviewDecision(mode: null))).hasSchedule, isFalse);
    expect(build(mealPreviewFixture(decision: mealPreviewDecision(delay: -1))).delayMinutes, isNull);
    expect(build(mealPreviewFixture(decision: mealPreviewDecision(duration: 0))).hasSchedule, isFalse);
    expect(build(mealPreviewFixture(decision: mealPreviewDecision(grams: 0))).grams, isNull);
  });

  test('waiting differences use recorded stages and a positive deviation; missing carbs remain unknown', () {
    final details = mealPreviewFixture(decision: mealPreviewDecision(), history: [
      MealStatusHistoryEntryData(id: 1, mealId: 1, status: 'bolused-waiting', createdAt: at),
      MealStatusHistoryEntryData(id: 2, mealId: 1, status: 'waited-eating', createdAt: at.add(const Duration(minutes: 15))),
    ]);
    final result = const BuildMealApplicationReviewUseCase()(details, null);
    expect(result.actualWait, const Duration(minutes: 15));
    expect(result.waitComparison, MealWaitComparison.shorter);
    expect(result.waitDifference, const Duration(minutes: 5));
    expect(result.calculatorCarbs, isNull);
    expect(result.carbsMatch, isNull);
    expect(const BuildMealApplicationReviewUseCase()(details.copyWith(statusHistory: []), null).waitComparison, MealWaitComparison.unavailable);
  });
}
