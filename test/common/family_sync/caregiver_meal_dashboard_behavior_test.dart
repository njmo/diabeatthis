import 'package:diabeatthis/common/family_sync/presentation/family_planned_meal_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/meal_status_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard excludes terminal meals and preserves actionable states', () {
    for (final status in ['interrupted', 'skipped', 'summarized', 'unknown']) {
      expect(mealStatusAppearsOnDashboard(status), isFalse, reason: status);
    }
    for (final status in [
      'planned',
      'eaten',
      'eaten-extra',
      'eaten-bolused',
      ...mealStatusesBlockingAnotherMealActivation,
    ]) {
      expect(mealStatusAppearsOnDashboard(status), isTrue, reason: status);
    }
  });

  for (final monitoring in [false, true]) {
    testWidgets(
      'caregiver card opens preview directly: monitored=$monitoring',
      (tester) async {
        var opened = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyPlannedMealCard(
                payload: {
                  'name': 'Lunch',
                  'status': 'planned',
                  'planned_at': DateTime.now().millisecondsSinceEpoch,
                },
                history: const [],
                locked: monitoring,
                monitoring: monitoring,
                onOpen: () => opened++,
              ),
            ),
          ),
        );
        expect(find.byType(ExpansionTile), findsNothing);
        await tester.tap(find.text('Lunch'));
        expect(opened, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
