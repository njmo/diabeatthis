import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_dose_suggestion.dart';
import 'package:diabeatthis/features/meal_advisor/presentation/widgets/meal_activity_warning.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final phase in MealActivityPhase.values) {
    testWidgets('compact warning shows direct dose percent and $phase', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MealActivityWarning(
                suggestion: MealActivityDoseSuggestion(
                  dosePercent: 80,
                  activityName: 'Spacer',
                  startedAt: DateTime(2026, 11, 3, 14),
                  phase: phase,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Propozycja: 80% dawki'), findsOneWidget);
      expect(find.textContaining('Spacer'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.textContaining('mniej'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
