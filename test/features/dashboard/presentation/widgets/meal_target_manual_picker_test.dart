import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/dashboard/presentation/controllers/dashboard_status_controller.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_target_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('the meal picker highlights the current link and returns only the explicitly selected meal', (tester) async {
    final start = DateTime(2026, 11, 3, 9);
    final target = TemporaryTarget(nightscoutId: 'target', createdAt: start,
      durationInMiliseconds: 3600000, duration: 60, targetBottom: 90, targetTop: 90);
    int? selected;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        mealTargetCandidatesProvider(target).overrideWithValue(AsyncData([
          Meal(id: 1, name: 'Pierwszy posiłek', plannedAt: start),
          Meal(id: 2, name: 'Wybrany posiłek', plannedAt: start.add(const Duration(minutes: 20))),
        ])),
      ],
      child: localizedMaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async { selected = await showMealTargetPickerSheet(context, target, selectedMealId: 1); },
        child: const Text('Open'),
      )))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    await tester.tap(find.text('Wybrany posiłek'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });
}
