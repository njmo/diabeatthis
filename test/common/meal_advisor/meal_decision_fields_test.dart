import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_method_field.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_responses_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final paired in [false, true]) {
    testWidgets(
      'advisor selection enforces AI lock and family pairing: paired=$paired',
      (tester) async {
        final changes = <MealDecisionMethod>[];
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MealDecisionMethodField(
                value: MealDecisionMethod.app,
                caregiverAvailable: paired,
                onChanged: changes.add,
              ),
            ),
          ),
        );
        final ai = find.byWidgetPredicate(
          (w) =>
              w is RadioListTile<MealDecisionMethod> &&
              w.value == MealDecisionMethod.ai,
        );
        final caregiver = find.byWidgetPredicate(
          (w) =>
              w is RadioListTile<MealDecisionMethod> &&
              w.value == MealDecisionMethod.caregiver,
        );
        expect(
          tester.widget<RadioListTile<MealDecisionMethod>>(ai).enabled,
          isFalse,
        );
        expect(
          tester.widget<RadioListTile<MealDecisionMethod>>(caregiver).enabled,
          paired,
        );
        await tester.tap(ai);
        await tester.tap(caregiver);
        expect(changes, paired ? [MealDecisionMethod.caregiver] : isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'caregiver configuration explains delivery requirements and preserves opt out',
    (tester) async {
      bool? changed;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MealDecisionResponsesField(
              enabled: true,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      expect(find.textContaining('internet connection'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      expect(changed, isFalse);
    },
  );
}
