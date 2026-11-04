import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/recorded_meal_conversion_unavailable.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_completion_load_error.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in ['pl', 'en']) {
    testWidgets(
      'missing conversion has readable sheet with close and retry: $locale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var reads = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealCompletionContextProvider(1).overrideWith((ref) async {
                reads++;
                throw RecordedMealConversionUnavailable();
              }),
            ],
            child: MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: const EdgeInsets.only(bottom: 48),
                  viewPadding: const EdgeInsets.only(bottom: 48),
                  textScaler: const TextScaler.linear(1.5),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    child: const Text('Open'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const MealCompletionEntry(
                        mealId: 1,
                        compactChoice: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(MealCompletionLoadError));
        final lang = context.lang;
        expect(find.text(lang.mealCompletionMissingConversion), findsOneWidget);
        expect(find.text(lang.mealCompletionViewRecordedMeal), findsOneWidget);
        expect(find.textContaining('Bad state:'), findsNothing);
        final retry = find.text(lang.mealCompletionRetryLoad);
        await tester.ensureVisible(retry);
        expect(tester.getBottomRight(retry).dy, lessThan(844 - 48));
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(reads, 2);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(MealCompletionLoadError), findsNothing);
      },
    );
  }
}
