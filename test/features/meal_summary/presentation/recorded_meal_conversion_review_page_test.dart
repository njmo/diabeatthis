import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/recorded_meal_conversion_repository.dart';
import 'package:diabeatthis/common/meal/recorded_meal_conversion_request.dart';
import 'package:diabeatthis/common/meal/review_recorded_meal_conversion_use_case.dart';
import 'package:diabeatthis/common/widgets/meal_completion/recorded_meal_conversion_review_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeReviewUseCase implements ReviewRecordedMealConversionUseCase {
  final saved = <Map<RecordedMealConversionRequest, double>>[];
  bool fail = false;

  @override
  RecordedMealConversionRepository get repository => throw UnimplementedError();

  @override
  Future<List<RecordedMealConversionRequest>> load(int mealId) async => [];

  @override
  Future<void> confirm(
    Map<RecordedMealConversionRequest, double> reviewed,
  ) async {
    if (fail) throw StateError('changed');
    saved.add(Map.of(reviewed));
  }
}

RecordedMealConversionRequest request(int id, double? grams) =>
    RecordedMealConversionRequest(
      entryId: id,
      mealId: 1,
      ingredientId: id,
      portionId: id,
      ingredientName: 'Ingredient $id',
      portionName: 'Portion $id',
      amount: 2,
      currentGrams: grams,
    );

void main() {
  test('editable grams keep the exact stored value', () {
    for (final value in [55.5, 55.0, 12.345678, 1234.5]) {
      for (final locale in ['pl', 'en']) {
        expect(parseEditableGrams(formatEditableGrams(value, locale)), value);
      }
    }
    expect(formatEditableGrams(55.5, 'pl'), '55,5');
    expect(formatEditableGrams(55.5, 'en'), '55.5');
    expect(formatEditableGrams(1234.0, 'pl'), '1234');
  });

  for (final locale in ['pl', 'en']) {
    testWidgets('all missing weights are confirmed on one page: $locale', (
      tester,
    ) async {
      final useCase = FakeReviewUseCase();
      final first = request(1, 55.5);
      final second = request(2, null);
      bool? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRecordedMealConversionUseCaseProvider.overrideWithValue(
              useCase,
            ),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () async {
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => RecordedMealConversionReviewPage(
                          mealId: 1,
                          requests: [first, second],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final lang = tester
          .element(find.byType(RecordedMealConversionReviewPage))
          .lang;
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));
      expect(find.text('Ingredient 1'), findsOneWidget);
      expect(find.text('2 × Portion 1'), findsOneWidget);
      expect(find.text(locale == 'pl' ? '55,5' : '55.5'), findsOneWidget);
      expect(find.text(lang.mealConversionSuggestionHint), findsOneWidget);
      expect(find.text(lang.mealConversionNoSuggestion), findsOneWidget);

      // The weight without a suggestion must be entered explicitly.
      await tester.tap(find.text(lang.mealConversionConfirm));
      await tester.pumpAndSettle();
      expect(find.text(lang.mealConversionInvalidWeight), findsOneWidget);
      expect(useCase.saved, isEmpty);

      await tester.enterText(fields.at(1), '32,5');
      useCase.fail = true;
      await tester.tap(find.text(lang.mealConversionConfirm));
      await tester.pumpAndSettle();
      expect(find.text(lang.mealConversionSaveFailed), findsOneWidget);
      expect(find.text('32,5'), findsOneWidget);
      expect(result, isNull);

      useCase.fail = false;
      await tester.tap(find.text(lang.mealConversionConfirm));
      await tester.pumpAndSettle();
      expect(useCase.saved, [
        {first: 55.5, second: 32.5},
      ]);
      expect(result, isTrue);
    });
  }

  testWidgets('an empty weight far below the fold still blocks saving', (
    tester,
  ) async {
    final useCase = FakeReviewUseCase();
    final requests = [
      for (var i = 1; i <= 12; i++) request(i, i < 12 ? 40 : null),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRecordedMealConversionUseCaseProvider.overrideWithValue(
            useCase,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecordedMealConversionReviewPage(mealId: 1, requests: requests),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lang = tester
        .element(find.byType(RecordedMealConversionReviewPage))
        .lang;
    await tester.tap(find.text(lang.mealConversionConfirm));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(useCase.saved, isEmpty);
    expect(find.text(lang.mealConversionInvalidWeight), findsOneWidget);
    final save = find.ancestor(
      of: find.text(lang.mealConversionConfirm),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('closing the page saves nothing', (tester) async {
    final useCase = FakeReviewUseCase();
    bool? result = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRecordedMealConversionUseCaseProvider.overrideWithValue(
            useCase,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => RecordedMealConversionReviewPage(
                        mealId: 1,
                        requests: [request(1, 40)],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(useCase.saved, isEmpty);
  });
}
