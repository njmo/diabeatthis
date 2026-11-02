import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_portion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_ingredient_row.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_quantity_section.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_summary_extra_items_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  Future<ProviderContainer> open(
    WidgetTester tester, {
    MealCompletionPortionChoice? choice = MealCompletionPortionChoice.adjusted,
    ValueChanged<bool>? onValidityChanged,
    ValueChanged<MealCompletionPortionChoice>? onChoiceChanged,
    bool enabled = true,
    double textScale = 1,
    bool showConfidence = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        mealSummaryControllerProvider.overrideWith(
          CompletionQuantityTestController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Consumer(
                    builder: (context, ref, _) => ref
                        .watch(mealSummaryControllerProvider(1))
                        .when(
                          loading: () => const CircularProgressIndicator(),
                          error: (error, _) => Text('$error'),
                          data: (draft) => MealCompletionQuantitySection(
                            draft: draft,
                            choice: choice,
                            onChoiceChanged: onChoiceChanged ?? (_) {},
                            onInputValidityChanged: onValidityChanged ?? (_) {},
                            enabled: enabled,
                            showConfidence: showConfidence,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder row(int id) => find.byKey(ValueKey(id));
  Finder rowText(int id, String text) =>
      find.descendant(of: row(id), matching: find.text(text));
  double amount(ProviderContainer container, int id) => container
      .read(mealSummaryControllerProvider(1))
      .requireValue
      .itemsById[id]!
      .consumedAmount;

  testWidgets(
    'reported portion remains actionable after a failed immediate save',
    (tester) async {
      final selections = <MealCompletionPortionChoice>[];
      await open(
        tester,
        choice: MealCompletionPortionChoice.asReported,
        onChoiceChanged: selections.add,
      );
      expect(find.text('Zapisz podsumowanie od razu'), findsOneWidget);
      expect(find.text('Inaczej'), findsOneWidget);
      await tester.tap(find.text('Wszystko'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wszystko'));
      await tester.pumpAndSettle();
      expect(selections, [
        MealCompletionPortionChoice.asReported,
        MealCompletionPortionChoice.asReported,
      ]);
    },
  );

  testWidgets('immediate save and editing choices are disabled while saving', (
    tester,
  ) async {
    await open(
      tester,
      choice: MealCompletionPortionChoice.asReported,
      enabled: false,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });

  testWidgets(
    'primary action receives four fifths of the available button width',
    (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, choice: null);
      final primary = tester.getRect(find.byType(FilledButton));
      final secondary = tester.getRect(find.byType(OutlinedButton));
      expect(primary.width / secondary.width, closeTo(4, 0.001));
      expect(primary.top, secondary.top);
      expect(primary.height, greaterThanOrEqualTo(48));
      expect(secondary.width, greaterThanOrEqualTo(48));
      expect(secondary.height, greaterThanOrEqualTo(48));
    },
  );

  testWidgets(
    'actions stack without truncation on a narrow screen with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, choice: null, textScale: 1.6);
      final primary = tester.getRect(find.byType(FilledButton));
      final secondary = tester.getRect(find.byType(OutlinedButton));
      expect(primary.width, secondary.width);
      expect(secondary.top, greaterThan(primary.bottom));
      expect(find.text('Wszystko'), findsOneWidget);
      expect(find.text('Inaczej'), findsOneWidget);
    },
  );

  testWidgets(
    'adjusted choice exposes every ingredient and extra products directly',
    (tester) async {
      await open(tester);
      expect(find.byType(MealCompletionIngredientRow), findsNWidgets(2));
      expect(find.byType(FriendlyAmountSelector), findsNWidgets(2));
      expect(find.byType(MealSummaryExtraItemsSection), findsOneWidget);
      expect(rowText(1, 'Plan: 100 g'), findsOneWidget);
      expect(rowText(1, 'Zapisano: 150 g'), findsOneWidget);
      expect(find.text('Ilości składników i dokładność'), findsNothing);
      expect(
        tester
            .widget<FriendlyAmountSelector>(
              find.byType(FriendlyAmountSelector).first,
            )
            .compact,
        isTrue,
      );
      expect(
        find.descendant(of: row(1), matching: find.byType(IconButton)),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'nothing half and whole use the reported amount after earlier add-ons',
    (tester) async {
      final container = await open(tester);
      for (final entry in {
        'Nic': 0.0,
        'Połowa': 75.0,
        'Całość': 150.0,
      }.entries) {
        await tester.ensureVisible(rowText(1, entry.key));
        await tester.tap(rowText(1, entry.key));
        await tester.pumpAndSettle();
        expect(amount(container, 1), entry.value);
      }
    },
  );

  testWidgets(
    'ingredient changes allow less and more together with separate units',
    (tester) async {
      final container = await open(tester);
      await tester.ensureVisible(rowText(1, 'Połowa'));
      await tester.tap(rowText(1, 'Połowa'));
      await tester.pumpAndSettle();
      final increase = find.descendant(
        of: row(2),
        matching: find.byIcon(Icons.add),
      );
      await tester.ensureVisible(increase);
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(amount(container, 1), 75);
      expect(amount(container, 2), 2.5);
      expect(rowText(1, '75 g'), findsOneWidget);
      expect(rowText(2, '2,5 szt.'), findsOneWidget);
    },
  );

  testWidgets(
    'manual entry blocks parent saving until confirmed and accepts more than double',
    (tester) async {
      final validity = <bool>[];
      final container = await open(tester, onValidityChanged: validity.add);
      await tester.ensureVisible(rowText(1, '150 g'));
      await tester.tap(rowText(1, '150 g'));
      await tester.pumpAndSettle();
      expect(validity.last, isFalse);
      for (final input in ['', '-10', 'NaN']) {
        await tester.enterText(find.byType(TextFormField), input);
        await tester.tap(find.text('Zatwierdź'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(validity.last, isFalse);
        expect(amount(container, 1), 150);
      }
      await tester.enterText(find.byType(TextFormField), '375');
      await tester.tap(find.text('Zatwierdź'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(validity.last, isTrue);
      expect(amount(container, 1), 375);
      expect(rowText(1, '375 g'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelling invalid manual entry restores validity without changing the amount',
    (tester) async {
      final validity = <bool>[];
      final container = await open(tester, onValidityChanged: validity.add);
      await tester.ensureVisible(rowText(1, '150 g'));
      await tester.tap(rowText(1, '150 g'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(validity, [false, true]);
      expect(amount(container, 1), 150);
    },
  );

  testWidgets(
    'late reporting confidence is editable directly below each ingredient',
    (tester) async {
      final container = await open(tester, showConfidence: true);
      await tester.ensureVisible(rowText(1, 'Jak dobrze to pamiętasz?'));
      expect(find.byType(ExpansionTile), findsNothing);
      final slider = find.descendant(of: row(1), matching: find.byType(Slider));
      tester.widget<Slider>(slider).onChanged!(3);
      await tester.pumpAndSettle();
      expect(
        container
            .read(mealSummaryControllerProvider(1))
            .requireValue
            .itemsById[1]!
            .consumedConfidence,
        0.95,
      );
      expect(amount(container, 1), 150);
    },
  );

  testWidgets('compact rows fit a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, textScale: 1.6);
    await tester.ensureVisible(rowText(2, 'Całość'));
    await tester.pumpAndSettle();
  });
}

class CompletionQuantityTestController extends MealSummaryControllerNotifier {
  @override
  Future<MealSummaryDraft> build(int mealId) async => const MealSummaryDraft(
    mealId: 1,
    mealStatus: 'eating',
    itemIds: [1, 2],
    itemsById: {
      1: MealSummaryItemDraft(
        name: 'Rice',
        mealIngredientId: 1,
        plannedAmount: 100,
        reportedAmount: 150,
        amountLabel: 'g',
        netCarbsPerAmount: 0.2,
        consumedAmount: 150,
        consumedConfidence: 0.8,
        gramsPerAmount: 1,
      ),
      2: MealSummaryItemDraft(
        name: 'Bread',
        mealIngredientId: 2,
        plannedAmount: 2,
        reportedAmount: 2,
        amountLabel: 'szt.',
        netCarbsPerAmount: 10,
        consumedAmount: 2,
        consumedConfidence: 0.75,
        gramsPerAmount: 35,
      ),
    },
    extraItems: [],
  );
}
