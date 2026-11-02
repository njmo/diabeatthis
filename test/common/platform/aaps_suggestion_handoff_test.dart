import 'dart:async';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/platform/aaps_suggestion_prompt.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/utils/fake_notifications_controller.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  const initialEatingInstruction = AapsBolusSuggestionNotificationEvent(
    mealId: 42,
    carbs: 0,
    extendedCarbs: 11,
    extendedCarbsDelayMinutes: 60,
    extendedCarbsDurationMinutes: 180,
  );

  Future<AapsHandoffTestSession> start(
    WidgetTester tester, {
    required HandoffNotificationsController notifications,
    required HandoffAapsLauncher launcher,
  }) async {
    final session = AapsHandoffTestSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsControllerUiProvider.overrideWithValue(notifications),
          aapsLauncherProvider.overrideWithValue(launcher),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () {
                  session.operation = openAapsWithSuggestionNotification(
                    context: context,
                    ref: ref,
                    event: initialEatingInstruction,
                  );
                },
                child: const Text('Start eating'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start eating'));
    return session;
  }

  testWidgets(
    'initial eating eCarbs instruction is published before opening AAPS',
    (tester) async {
      final operations = <String>[];
      final notifications = HandoffNotificationsController(operations);
      final launcher = HandoffAapsLauncher(
        operations,
        onOpen: () {
          expect(notifications.shownEvents, [initialEatingInstruction]);
          final instruction =
              notifications.shownEvents.single
                  as AapsBolusSuggestionNotificationEvent;
          expect(instruction.carbs, 0);
          expect(instruction.extendedCarbs, 11);
          expect(instruction.extendedCarbsDelayMinutes, 60);
          expect(instruction.extendedCarbsDurationMinutes, 180);
        },
      );
      final session = await start(
        tester,
        notifications: notifications,
        launcher: launcher,
      );
      await tester.pumpAndSettle();
      await session.operation;
      expect(operations, ['notification', 'published', 'launch']);
      expect(launcher.opens, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('a pending notification must finish before the external launch', (
    tester,
  ) async {
    final operations = <String>[];
    final pending = Completer<void>();
    final notifications = HandoffNotificationsController(
      operations,
      waitForShow: pending.future,
    );
    final launcher = HandoffAapsLauncher(operations);
    final session = await start(
      tester,
      notifications: notifications,
      launcher: launcher,
    );
    await tester.pump();
    expect(operations, ['notification']);
    expect(launcher.opens, 0);
    pending.complete();
    await tester.pumpAndSettle();
    await session.operation;
    expect(operations, ['notification', 'published', 'launch']);
    expect(notifications.shownEvents, [initialEatingInstruction]);
  });

  testWidgets(
    'notification failure shows the exact instruction before explicit continue',
    (tester) async {
      final operations = <String>[];
      final notifications = HandoffNotificationsController(
        operations,
        showError: StateError('Notification unavailable'),
      );
      final launcher = HandoffAapsLauncher(operations);
      final session = await start(
        tester,
        notifications: notifications,
        launcher: launcher,
      );
      await tester.pumpAndSettle();
      expect(launcher.opens, 0);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(lang.aapsSuggestionUnavailableTitle), findsOneWidget);
      expect(find.text(lang.aapsSuggestionUnavailableMessage), findsOneWidget);
      expect(find.text(initialEatingInstruction.title), findsOneWidget);
      await tester.tap(find.text(lang.mealProgressOpenCalculator));
      await tester.pumpAndSettle();
      await session.operation;
      expect(launcher.opens, 1);
      expect(operations, ['notification', 'launch']);
      expect(notifications.shownEvents, isEmpty);
    },
  );

  testWidgets('cancelling the fallback leaves AAPS closed', (tester) async {
    final operations = <String>[];
    final notifications = HandoffNotificationsController(
      operations,
      showError: StateError('Notification unavailable'),
    );
    final launcher = HandoffAapsLauncher(operations);
    final session = await start(
      tester,
      notifications: notifications,
      launcher: launcher,
    );
    await tester.pumpAndSettle();
    expect(find.text(initialEatingInstruction.title), findsOneWidget);
    await tester.tap(find.text(lang.settingsCancel));
    await tester.pumpAndSettle();
    await session.operation;
    expect(launcher.opens, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(operations, ['notification']);
  });

  testWidgets(
    'launcher failure keeps the posted instruction and explains manual opening',
    (tester) async {
      final operations = <String>[];
      final notifications = HandoffNotificationsController(operations);
      final launcher = HandoffAapsLauncher(
        operations,
        result: AapsLaunchResult.failed,
      );
      final session = await start(
        tester,
        notifications: notifications,
        launcher: launcher,
      );
      await tester.pumpAndSettle();
      await session.operation;
      expect(notifications.shownEvents, [initialEatingInstruction]);
      expect(notifications.cancelledIds, isEmpty);
      expect(notifications.cancelAllCalled, isFalse);
      expect(find.text(lang.aapsOpenFailed), findsOneWidget);
      expect(operations, ['notification', 'published', 'launch']);
    },
  );
}

class AapsHandoffTestSession {
  Future<void>? operation;
}

class HandoffNotificationsController extends FakeNotificationsController {
  HandoffNotificationsController(
    this.operations, {
    this.waitForShow,
    this.showError,
  });

  final List<String> operations;
  final Future<void>? waitForShow;
  final Object? showError;

  @override
  Future<void> show(NotificationEvent event) async {
    operations.add('notification');
    if (waitForShow != null) await waitForShow;
    if (showError != null) throw showError!;
    await super.show(event);
    operations.add('published');
  }
}

class HandoffAapsLauncher extends AapsLauncher {
  HandoffAapsLauncher(
    this.operations, {
    this.onOpen,
    this.result = AapsLaunchResult.opened,
  });

  final List<String> operations;
  final VoidCallback? onOpen;
  final AapsLaunchResult result;
  int opens = 0;

  @override
  Future<AapsLaunchResult> openAaps() async {
    operations.add('launch');
    opens++;
    onOpen?.call();
    return result;
  }
}
