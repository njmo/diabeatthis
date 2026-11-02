import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_aaps_suggestion.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/open_meal_summary_aaps_suggestion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../helpers/localized_material_app.dart';

void main() {
  const schedule = ExtendedCarbsScheduleSettings(
    delayMinutes: 45,
    durationMinutes: 120,
  );

  setUp(() => LanguageStrings.setSelectedLocale(const Locale('pl')));
  tearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));

  test(
    'initial zero-carbs eCarbs instruction keeps its original wording and defaults',
    () {
      final event = buildMealSummaryAapsSuggestionEvent(
        aapsCarbs: const MealSummaryAapsCarbs(carbs: 0, extendedCarbs: 12),
        extendedCarbsScheduleSettings: schedule,
      )!;
      expect(event.extendedCarbsAreAdditional, isFalse);
      expect(event.title, 'Wpisz extended 12g za 45 min przez 2 godz.');
      expect(event.toJson().containsKey('extendedCarbsAreAdditional'), isFalse);
      final restored = AapsBolusSuggestionNotificationEvent.fromPayload(
        event.toJson(),
      );
      expect(restored.extendedCarbsAreAdditional, isFalse);
      expect(restored.title, event.title);
    },
  );

  test(
    'additional flag changes only the eCarbs portion and survives serialization',
    () {
      final event = buildMealSummaryAapsSuggestionEvent(
        mealId: 73,
        aapsCarbs: const MealSummaryAapsCarbs(carbs: 37, extendedCarbs: 12),
        extendedCarbsScheduleSettings: schedule,
        extendedCarbsAreAdditional: true,
      )!;
      expect(
        event.title,
        'Podaj 37g, dodatkowe eCarbs: 12 g za 45 min przez 2 godz.',
      );
      final restored = AapsBolusSuggestionNotificationEvent.fromPayload(
        event.toJson(),
      );
      expect(restored.extendedCarbsAreAdditional, isTrue);
      expect(restored.mealId, 73);
      expect(restored.carbs, 37);
      expect(restored.extendedCarbs, 12);
      expect(restored.extendedCarbsDelayMinutes, 45);
      expect(restored.extendedCarbsDurationMinutes, 120);
      expect(restored.title, event.title);
    },
  );

  test(
    'additional eCarbs without ordinary carbs retains the scheduled instruction',
    () {
      const event = AapsBolusSuggestionNotificationEvent(
        carbs: 0,
        extendedCarbs: 12,
        extendedCarbsAreAdditional: true,
        extendedCarbsDelayMinutes: 45,
        extendedCarbsDurationMinutes: 120,
      );
      expect(
        event.title,
        'Wpisz dodatkowe eCarbs: 12 g za 45 min przez 2 godz.',
      );
    },
  );

  test(
    'ordinary carbs are not labeled additional when no eCarbs are present',
    () {
      const event = AapsBolusSuggestionNotificationEvent(
        carbs: 37,
        extendedCarbsAreAdditional: true,
      );
      expect(event.title, 'Podaj 37g');
    },
  );

  testWidgets(
    'the new completion and add-on opener marks only its extended portion additional',
    (tester) async {
      final notifications = FakeNotificationsController();
      final launcher = AdditionalExtendedCarbsLauncher();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsControllerUiProvider.overrideWithValue(notifications),
            aapsLauncherProvider.overrideWithValue(launcher),
            extendedCarbsScheduleSettingsProvider.overrideWith(
              (ref) async => schedule,
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => openMealAapsCarbsSuggestion(
                    context: context,
                    ref: ref,
                    mealId: 73,
                    aapsCarbs: const MealSummaryAapsCarbs(
                      carbs: 37,
                      extendedCarbs: 12,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final event =
          notifications.shownEvents.single
              as AapsBolusSuggestionNotificationEvent;
      expect(event.extendedCarbsAreAdditional, isTrue);
      expect(event.carbs, 37);
      expect(event.extendedCarbs, 12);
      expect(launcher.opens, 1);
    },
  );
}

class AdditionalExtendedCarbsLauncher extends AapsLauncher {
  int opens = 0;

  @override
  Future<AapsLaunchResult> openAaps() async {
    opens++;
    return AapsLaunchResult.opened;
  }
}
