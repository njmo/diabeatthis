import 'package:auto_route/auto_route.dart';
import 'package:diabeatthis/app/router/app_router.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_ingredient_row.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<RootStackRouter> open(
    WidgetTester tester,
    String status, {
    Meal? blockingMeal,
    double reportedAmount = 100,
  }) async {
    final router = RootStackRouter.build(
      routes: [
        AutoRoute(page: MealSummaryRoute.page, path: '/meal-summary/:mealId'),
      ],
    );
    addTearDown(router.dispose);
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealSummaryControllerProvider.overrideWith(
            () => AddOnNavigationController(status, reportedAmount),
          ),
          mealCompletionContextProvider(1).overrideWith(
            (ref) async => MealCompletionContext(
              meal: Meal(id: 1, name: 'Lunch', status: status),
              timing: MealCompletionTiming(
                startedAt: now.subtract(const Duration(minutes: 20)),
                endedAt: now,
                endStatus: status,
              ),
            ),
          ),
          mealBlockingActivationProvider(
            1,
          ).overrideWith((ref) async => blockingMeal),
        ],
        child: MaterialApp.router(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(
            deepLinkBuilder: (_) =>
                DeepLink([MealSummaryRoute(mealId: 1, finishEating: true)]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> openAdjustedAmounts(WidgetTester tester) async {
    final button = find.text('Inaczej');
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  for (final status in ['eaten', 'eaten-bolused']) {
    testWidgets(
      'adjusted amounts for $status use the current editor without a legacy transition',
      (tester) async {
        final router = await open(tester, status);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealCompletionView)),
        );
        container
            .read(mealSummaryControllerProvider(1).notifier)
            .setConsumedAmount(1, 60);
        await tester.pumpAndSettle();
        await openAdjustedAmounts(tester);
        expect(find.text('Zapisz dokładkę i wróć do jedzenia'), findsNothing);
        expect(find.byType(MealCompletionView), findsOneWidget);
        expect(find.byType(MealCompletionIngredientRow), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Dokładka'), findsNothing);
        expect(router.stack, hasLength(1));
        expect(
          router.current.argsAs<MealSummaryRouteArgs>().finishEating,
          isTrue,
        );
        expect(
          container
              .read(mealSummaryControllerProvider(1))
              .requireValue
              .itemsById[1]!
              .consumedAmount,
          60,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('another active meal does not block editing the completed meal', (
    tester,
  ) async {
    final router = await open(
      tester,
      'eaten',
      blockingMeal: const Meal(id: 2, name: 'QM: Dinner', status: 'eating'),
    );
    await openAdjustedAmounts(tester);
    expect(router.current.argsAs<MealSummaryRouteArgs>().finishEating, isTrue);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(MealCompletionIngredientRow), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Dokładka'), findsNothing);
    expect(find.text('Zapisz dokładkę i wróć do jedzenia'), findsNothing);
  });

  for (final status in ['eating', 'eating-then-bolus', 'eaten-extra']) {
    testWidgets('completion for $status has no continue-eating add-on route', (
      tester,
    ) async {
      await open(tester, status);
      await openAdjustedAmounts(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Dokładka'), findsNothing);
    });
  }

  testWidgets('previously reported add-on remains the amount baseline', (
    tester,
  ) async {
    await open(tester, 'eaten', reportedAmount: 150);
    await openAdjustedAmounts(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MealCompletionView)),
    );
    final item = container
        .read(mealSummaryControllerProvider(1))
        .requireValue
        .itemsById[1]!;
    expect(item.reportedAmount, 150);
    expect(item.consumedAmount, 150);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, 'Dokładka'), findsNothing);
  });
}

class AddOnNavigationController extends MealSummaryControllerNotifier {
  AddOnNavigationController(this.status, this.reportedAmount);

  final String status;
  final double reportedAmount;

  @override
  Future<MealSummaryDraft> build(int mealId) async => MealSummaryDraft(
    mealId: mealId,
    mealStatus: status,
    itemIds: [1],
    itemsById: {
      1: MealSummaryItemDraft(
        name: 'Rice',
        mealIngredientId: 1,
        plannedAmount: 100,
        reportedAmount: reportedAmount,
        amountLabel: 'g',
        netCarbsPerAmount: 0.2,
        consumedAmount: reportedAmount,
        consumedConfidence: 0.8,
        gramsPerAmount: 1,
      ),
    },
    extraItems: [],
  );
}
