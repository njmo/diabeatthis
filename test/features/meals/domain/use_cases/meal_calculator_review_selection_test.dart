import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_assignment.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/domain/use_cases/build_meal_application_review_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/tasks/meal_monitor_test.dart' show testBolusWizard;
import '../../fixtures/meal_preview_fixture.dart';

void main() {
  final at = DateTime(2026, 11, 3, 12);
  final first = testBolusWizard(createdAt: at, carbs: 40, nightscoutObjectId: 'wizard-1').copyWith(remoteSource: 'source-a');
  final second = testBolusWizard(createdAt: at.add(const Duration(seconds: 1)), carbs: 100, nightscoutObjectId: 'wizard-2').copyWith(remoteSource: 'source-a');
  MealWizardAssignment link(String id, {String source = 'source-a', bool dismissed = false}) => MealWizardAssignment(
    id: id == 'wizard-1' ? 1 : 2, mealId: 1, localId: null, remoteId: id, remoteSource: source,
    type: MealWizardRelationType.initial, dismissed: dismissed,
  );
  MealAnalysisData history(List<BolusWizard> wizards) => MealAnalysisData(
    chartStart: at, chartEnd: at.add(const Duration(hours: 1)), expectedChartEnd: at.add(const Duration(hours: 1)),
    eventStart: at.subtract(const Duration(hours: 1)), eventEnd: at.add(const Duration(hours: 1)), mealTime: at,
    glucoseReadings: const [], treatments: wizards, temporaryTargets: const [], deviceStatuses: const [],
    linkedActivities: const [], linkedMeals: const [], timelineEvents: const [],
  );

  test('a nearby unassigned calculator never substitutes for the explicitly linked one', () {
    final details = mealPreviewFixture().copyWith(wizardAssignments: [link('wizard-1')]);
    final review = const BuildMealApplicationReviewUseCase()(details, history([first, second]));
    expect(review.calculatorCount, 1);
    expect(review.calculatorCarbs, 40);
  });

  test('foreign sources, dismissals and multiple assigned calculators keep comparisons unambiguous', () {
    const build = BuildMealApplicationReviewUseCase();
    final details = mealPreviewFixture();
    expect(build(details.copyWith(wizardAssignments: [link('wizard-1', source: 'other')]), history([first])).calculatorCarbs, isNull);
    expect(build(details.copyWith(wizardAssignments: [link('wizard-1', dismissed: true)]), history([first])).calculatorCarbs, isNull);
    final multiple = build(details.copyWith(wizardAssignments: [link('wizard-1'), link('wizard-2')]), history([first, second]));
    expect(multiple.calculatorCount, 2);
    expect(multiple.calculatorCarbs, isNull);
  });
}
