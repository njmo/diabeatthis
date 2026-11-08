import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/context/caregiver_meal_context_history.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/caregiver_meal_context_history_view.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('future extended carbs are labelled scheduled, not ongoing', (
    tester,
  ) async {
    LanguageStrings.setSelectedLocale(const Locale('en'));
    addTearDown(() => LanguageStrings.setSelectedLocale(null));
    final now = DateTime(2026, 11, 8, 12);
    final history = CaregiverMealContextHistory(
      asOf: now,
      glucose: const [],
      devices: const [],
      treatments: [
        ExtendedCarb(
          externalId: 'future',
          createdAt: now.add(const Duration(hours: 1)),
          carbs: 20,
          duration: const Duration(hours: 2).inMilliseconds,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CaregiverMealContextHistoryView(history: history),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Scheduled eCarbs 20 g'), findsOneWidget);
    expect(find.text('eCarbs 20 g · 13:00–15:00'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
