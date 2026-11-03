import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/platform/aaps_suggestion_pip.dart';
import 'package:diabeatthis/common/platform/aaps_suggestion_prompt.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/utils/fake_notifications_controller.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pl.diabeatthis.app/suggestion_pip');
  const overlayChannel = MethodChannel('pl.diabeatthis.app/suggestion_overlay');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final strings = lookupAppLocalizations(const Locale('pl'));
  const suggestion = AapsBolusSuggestionNotificationEvent(
    carbs: 30,
    extendedCarbs: 15,
    extendedCarbsDelayMinutes: 45,
    extendedCarbsDurationMinutes: 120,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    LanguageStrings.setSelectedLocale(const Locale('pl'));
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(overlayChannel, null);
    debugDefaultTargetPlatformOverride = null;
    LanguageStrings.setSelectedLocale(null);
  });

  test(
    'sends the localized heading and exact suggestion schedule to the overlay',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'openAaps');
        expect(call.arguments['packageName'], 'info.nightscout.androidaps');
        expect(call.arguments['title'], strings.aapsSuggestionTitle);
        expect(call.arguments['closeLabel'], strings.aapsSuggestionClose);
        expect(call.arguments['labels'], ['Carbs', 'E-carbs', 'Czas']);
        expect(call.arguments['values'], [
          '30 g',
          '15 g',
          strings.aapsPipSchedule(
            strings.durationMinutesShort(45),
            strings.durationHoursShort(2),
          ),
        ]);
        return true;
      });
      expect(
        await const AapsSuggestionPip().open(
          event: suggestion,
          strings: strings,
        ),
        isTrue,
      );
    },
  );

  test(
    'unavailable or denied PiP leaves the regular AAPS handoff available',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      expect(
        await const AapsSuggestionPip().open(
          event: suggestion,
          strings: strings,
        ),
        isFalse,
      );
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(
        await const AapsSuggestionPip().open(
          event: suggestion,
          strings: strings,
        ),
        isFalse,
      );
      messenger.setMockMethodCallHandler(channel, null);
      expect(
        await const AapsSuggestionPip().open(
          event: suggestion,
          strings: strings,
        ),
        isFalse,
      );
    },
  );

  test('hides extended carbs and schedule for immediate carbs', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['labels'], ['Carbs']);
      expect(call.arguments['values'], ['30 g']);
      return true;
    });
    expect(
      await const AapsSuggestionPip().open(
        event: const AapsBolusSuggestionNotificationEvent(
          carbs: 30,
          extendedCarbsAreAdditional: true,
        ),
        strings: strings,
      ),
      isTrue,
    );
  });

  test('uses the meal name in the branded heading', () async {
    const event = AapsBolusSuggestionNotificationEvent(
      carbs: 30,
      mealName: 'Lunch with potatoes',
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['title'], 'Lunch with potatoes');
      expect(call.arguments['closeLabel'], strings.aapsSuggestionClose);
      return true;
    });
    expect(
      AapsBolusSuggestionNotificationEvent.fromPayload(event.toJson()).mealName,
      event.mealName,
    );
    expect(
      await const AapsSuggestionPip().open(event: event, strings: strings),
      isTrue,
    );
  });

  testWidgets(
    'successful overlay replaces the notification and launches AAPS only once',
    (tester) async {
      final notifications = FakeNotificationsController();
      final launcher = UnexpectedPipFallbackLauncher();
      messenger.setMockMethodCallHandler(channel, (_) async {
        expect(notifications.shownEvents, isEmpty);
        return true;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aapsSuggestionPipProvider.overrideWithValue(
              const AapsSuggestionPip(),
            ),
            aapsLauncherProvider.overrideWithValue(launcher),
            notificationsControllerUiProvider.overrideWithValue(notifications),
          ],
          child: localizedMaterialApp(
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => openAapsWithSuggestionNotification(
                  context: context,
                  ref: ref,
                  event: suggestion,
                ),
                child: const Text('Open AAPS'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open AAPS'));
      await tester.pumpAndSettle();
      expect(launcher.opens, 0);
      expect(notifications.shownEvents, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  for (final overlayAvailable in [true, false]) {
    testWidgets('overlay is preferred with PiP fallback: $overlayAvailable', (
      tester,
    ) async {
      final notifications = FakeNotificationsController();
      final launcher = UnexpectedPipFallbackLauncher();
      var pipCalls = 0;
      messenger.setMockMethodCallHandler(overlayChannel, (call) async {
        expect(call.arguments['title'], strings.aapsSuggestionTitle);
        return overlayAvailable;
      });
      messenger.setMockMethodCallHandler(channel, (_) async {
        pipCalls++;
        return true;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aapsSuggestionOverlayProvider.overrideWithValue(
              const AapsSuggestionPip(
                channelName: 'pl.diabeatthis.app/suggestion_overlay',
              ),
            ),
            aapsSuggestionPipProvider.overrideWithValue(
              const AapsSuggestionPip(),
            ),
            aapsLauncherProvider.overrideWithValue(launcher),
            notificationsControllerUiProvider.overrideWithValue(notifications),
          ],
          child: localizedMaterialApp(
            home: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => openAapsWithSuggestionNotification(
                  context: context,
                  ref: ref,
                  event: suggestion,
                ),
                child: const Text('Open AAPS'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open AAPS'));
      await tester.pumpAndSettle();
      expect(pipCalls, overlayAvailable ? 0 : 1);
      expect(launcher.opens, 0);
      expect(notifications.shownEvents, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  test('does not call Android on other platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => fail('Unexpected Android call'),
    );
    expect(
      await const AapsSuggestionPip().open(event: suggestion, strings: strings),
      isFalse,
    );
  });
}

class UnexpectedPipFallbackLauncher extends AapsLauncher {
  int opens = 0;

  @override
  Future<AapsLaunchResult> openAaps() async {
    opens++;
    return AapsLaunchResult.opened;
  }
}
