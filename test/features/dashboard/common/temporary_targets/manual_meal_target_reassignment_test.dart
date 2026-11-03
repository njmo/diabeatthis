import 'package:diabeatthis/common/temporary_targets/owned_temp_target.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/dashboard/common/temporary_targets/meal_target_links.dart';
import 'package:diabeatthis/features/dashboard/domain/use_cases/resolve_meal_target_link_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a manually changed meal link survives reload and overrides the original association', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const source = 'https://example.com';
    final start = DateTime(2026, 11, 3, 9);
    final target = TemporaryTarget(nightscoutId: 'meal-target', createdAt: start,
      durationInMiliseconds: 3600000, duration: 60, targetBottom: 90, targetTop: 90);
    final owned = OwnedTempTarget(entityId: 1, targetType: 'meal', source: source, startedAt: start,
      until: start.add(const Duration(hours: 1)), target: 90, durationMinutes: 60, nightscoutId: 'meal-target');
    final original = TempTargetOperation(requestId: 'meal-offer', kind: TempTargetOperationKind.start,
      entityId: 1, targetType: 'meal', source: source, status: TempTargetOperationStatus.sent,
      createdAt: start, updatedAt: start, confirmedTarget: owned);
    await MealTargetLinks(prefs).attach(source, target, 2);
    await prefs.reload();
    final links = MealTargetLinks(prefs);
    expect(const ResolveMealTargetLinkUseCase()(source: source, target: target,
      manualMealId: links.mealId(source, target), operations: [original]), 2);
    expect(links.mealId('https://other.example.com', target), isNull);
  });
}
