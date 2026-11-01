import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/meal_start/meal_advice_unavailable.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final reason in [
    MealAdviceEligibility.missingDeviceStatus,
    MealAdviceEligibility.staleDeviceStatus,
    MealAdviceEligibility.incompleteDeviceStatus,
    MealAdviceEligibility.invalidDeviceStatus,
  ]) {
    testWidgets(
      '$reason explains the status problem without claiming CGM is missing',
      (tester) async {
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(body: MealAdviceUnavailable(reason: reason)),
          ),
        );
        expect(
          find.textContaining('Brak aktualnych danych do automatycznej porady'),
          findsOneWidget,
        );
        expect(find.textContaining('CGM'), findsNothing);
        expect(
          find.textContaining(
            reason == MealAdviceEligibility.invalidDeviceStatus
                ? 'nieprawidłowe dane'
                : reason == MealAdviceEligibility.incompleteDeviceStatus
                ? 'IOB lub COB'
                : 'IOB/COB',
          ),
          findsOneWidget,
        );
      },
    );
  }

  for (final (reason, fragment) in [
    (
      MealAdviceEligibility.insufficientReadings,
      'trzech kolejnych odczytów CGM',
    ),
    (MealAdviceEligibility.staleReadings, 'co najmniej 10 minut'),
    (MealAdviceEligibility.discontinuousReadings, 'nie tworzą ciągłej serii'),
    (MealAdviceEligibility.historyUnavailable, 'Nie udało się pobrać historii'),
  ]) {
    testWidgets('$reason distinguishes the history problem', (tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(body: MealAdviceUnavailable(reason: reason)),
        ),
      );
      expect(find.textContaining(fragment), findsOneWidget);
      expect(find.textContaining('IOB/COB'), findsNothing);
    });
  }

  testWidgets('retry is explicit and invokes the supplied action', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MealAdviceUnavailable(
            reason: MealAdviceEligibility.historyUnavailable,
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    expect(retries, 0);
    await tester.tap(find.text('Sprawdź ponownie'));
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('unknown reason retains the existing requirements', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(home: const Scaffold(body: MealAdviceUnavailable())),
    );
    expect(find.textContaining('3 kolejne odczyty CGM'), findsOneWidget);
    expect(find.textContaining('IOB/COB młodsze niż 6 minut'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('available data does not display an unavailable message', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: MealAdviceUnavailable(
            reason: MealAdviceEligibility.available,
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('English locale describes device status instead of CGM', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: MealAdviceUnavailable(
            reason: MealAdviceEligibility.staleDeviceStatus,
          ),
        ),
      ),
    );
    expect(find.textContaining('IOB/COB data is not current'), findsOneWidget);
    expect(find.textContaining('less than 6 minutes'), findsOneWidget);
    expect(find.textContaining('CGM'), findsNothing);
  });
}
