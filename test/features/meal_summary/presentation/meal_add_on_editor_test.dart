import 'package:diabeatthis/common/meal/open_meal_add_on.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/record_meal_add_on_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_add_on_editor.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_ingredient_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/localized_material_app.dart';
import 'meal_add_on_draft_test.dart' show addOnDraft;

void main() {
  const meal = Meal(id: 1, name: 'Lunch', status: 'eating');
  late List<MealSummaryDraft> saves;
  late FakeNotificationsController notifications;
  late AddOnTestAapsLauncher launcher;

  setUp(() {
    saves = [];
    notifications = FakeNotificationsController();
    launcher = AddOnTestAapsLauncher();
  });

  Future<void> open(WidgetTester tester, {int pendingCarbs = 0}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith(
            (ref) =>
                throw StateError('The recording use case owns persistence'),
          ),
          mealSummaryControllerProvider.overrideWith(
            AddOnEditorTestController.new,
          ),
          recordMealAddOnUseCaseProvider.overrideWith(
            (ref) => RecordingAddOnUseCase(
              ref: ref,
              saves: saves,
              pendingCarbs: pendingCarbs,
            ),
          ),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          aapsLauncherProvider.overrideWithValue(launcher),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    openMealAddOn(context: context, ref: ref, meal: meal),
                child: const Text('Open extra food'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open extra food'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Jem dokładkę');
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

  for (final preset in [('1,5× całości', 1.5), ('2× całości', 2.0)]) {
    testWidgets(
      '${preset.$1} uses the shared ingredient editor and returns to eating',
      (tester) async {
        await open(tester);
        await tester.tap(find.text(preset.$1));
        await tester.pumpAndSettle();
        expect(find.byType(MealAddOnEditor), findsOneWidget);
        expect(find.byType(MealCompletionIngredientRow), findsNWidgets(2));
        expect(find.byType(MealCompletionView), findsNothing);
        expect(saves, isEmpty);
        await save(tester);
        expect(saves, hasLength(1));
        expect(saves.single.itemsById[1]!.consumedAmount, preset.$2);
        expect(saves.single.itemsById[2]!.consumedAmount, 200 * preset.$2);
        expect(saves.single.itemsById[1]!.consumedConfidence, 0.75);
        expect(saves.single.mealStatus, 'eating');
        expect(find.byType(MealAddOnEditor), findsNothing);
        expect(find.text('Open extra food'), findsOneWidget);
        expect(launcher.opens, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'manual second meatball leaves potatoes unchanged and opens the calculator',
    (tester) async {
      await open(tester, pendingCarbs: 17);
      await tester.tap(find.text('Ręcznie'));
      await tester.pumpAndSettle();
      final row = find.byType(MealCompletionIngredientRow).first;
      final more = find.descendant(of: row, matching: find.byIcon(Icons.add));
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      await save(tester);
      expect(saves.single.itemsById[1]!.consumedAmount, 2);
      expect(saves.single.itemsById[1]!.consumedConfidence, 1);
      expect(saves.single.itemsById[2]!.consumedAmount, 200);
      expect(saves.single.itemsById[2]!.consumedConfidence, 0.5);
      final event =
          notifications.shownEvents.single
              as AapsBolusSuggestionNotificationEvent;
      expect(event.carbs, 17);
      expect(launcher.opens, 1);
      expect(find.byType(MealCompletionView), findsNothing);
      expect(find.text('Open extra food'), findsOneWidget);
    },
  );

  testWidgets('leaving a preset editor never records the add-on', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('1,5× całości'));
    await tester.pumpAndSettle();
    final backButton = find.byType(BackButton);
    expect(backButton, findsOneWidget);
    final backTooltip = MaterialLocalizations.of(
      tester.element(backButton),
    ).backButtonTooltip;
    expect(find.byTooltip(backTooltip), findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    expect(saves, isEmpty);
    expect(notifications.shownEvents, isEmpty);
    expect(find.text('Open extra food'), findsOneWidget);
  });

  testWidgets(
    'the choice and ingredient editor fit a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ręcznie'));
      await tester.tap(find.text('Ręcznie'));
      await tester.pumpAndSettle();
      expect(find.byType(MealAddOnEditor), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class AddOnEditorTestController extends MealSummaryControllerNotifier {
  @override
  Future<MealSummaryDraft> build(int mealId) async => addOnDraft();
}

class RecordingAddOnUseCase extends RecordMealAddOnUseCase {
  RecordingAddOnUseCase({
    required super.ref,
    required this.saves,
    required this.pendingCarbs,
  });

  final List<MealSummaryDraft> saves;
  final int pendingCarbs;

  @override
  Future<MealAddOnResult> call(MealSummaryDraft draft) async {
    saves.add(draft);
    return MealAddOnResult(
      meal: const Meal(id: 1, name: 'Lunch', status: 'eating-extra'),
      aapsCarbs: MealSummaryAapsCarbs(carbs: pendingCarbs, extendedCarbs: 0),
    );
  }
}

class AddOnTestAapsLauncher extends AapsLauncher {
  int opens = 0;

  @override
  Future<AapsLaunchResult> openAaps() async {
    opens++;
    return AapsLaunchResult.opened;
  }
}
