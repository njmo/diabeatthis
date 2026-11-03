import 'package:diabeatthis/features/dashboard/common/temporary_targets/meal_target_links.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final target = TemporaryTarget(
    nightscoutId: 'meal-target',
    createdAt: DateTime(2026, 11, 3, 8),
    durationInMiliseconds: 3600000,
    duration: 60,
    targetBottom: 110,
    targetTop: 110,
  );

  test('a confirmed display link persists and stays scoped to source and target', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await MealTargetLinks(prefs).attach('https://one.example', target, 42);
    await prefs.reload();
    final reopened = MealTargetLinks(prefs);
    expect(reopened.mealId('https://one.example', target), 42);
    expect(reopened.mealId('https://two.example', target), isNull);
    expect(reopened.mealId('https://one.example',
        target.copyWith(nightscoutId: 'replacement')), isNull);
    expect(reopened.mealId('https://one.example',
        target.copyWith(createdAt: target.createdAt.add(const Duration(minutes: 1)))), isNull);
  });

  test('invalid saved display data does not invent a meal link', () async {
    SharedPreferences.setMockInitialValues({MealTargetLinks.storageKey: 'broken'});
    final prefs = await SharedPreferences.getInstance();
    expect(MealTargetLinks(prefs).mealId('source', target), isNull);
  });
}
