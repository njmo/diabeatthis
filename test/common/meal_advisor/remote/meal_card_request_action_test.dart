import 'package:diabeatthis/common/family_sync/presentation/family_planned_meal_card.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the existing collapsed meal card exposes its decision request', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FamilyPlannedMealCard(
            payload: {
              'id': 1,
              'name': 'Lunch',
              'status': 'planned',
              'purpose': 'meal',
              'planned_at': DateTime.now().millisecondsSinceEpoch,
            },
            history: const [],
            locked: false,
            decisionAction: TextButton(
              onPressed: () => opened = true,
              child: const Text('Waiting for your decision'),
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Waiting for your decision').hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('Waiting for your decision'));
    expect(opened, isTrue);
    final tile = tester.widget<ExpansionTile>(find.byType(ExpansionTile));
    expect(tile.initiallyExpanded, isFalse);
  });
}
