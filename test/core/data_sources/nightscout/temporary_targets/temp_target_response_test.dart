import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/temp_target_response_event.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/notification_event_factory.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event.dart';
import 'package:diabeatthis/foreground/event/external/notification/notification_response_event_handler.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../foreground/utils/fake_notifications_controller.dart';
import '../../../../foreground/utils/fake_runtime_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'notification payload preserves consent and opening cannot authorize a write',
    () => withClock(Clock.fixed(DateTime(2026, 10, 29, 12)), () async {
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'https://example.com',
        nightscoutTokenKey: 'token',
        nightscoutTempTargetsEnabledKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      var calls = 0;
      final sent = Completer<void>();
      final service = TempTargetService(
        preferences: () async => prefs,
        database: () => db,
        writer: NightscoutTempTargetWriter(
          client: MockClient((_) async {
            calls++;
            sent.complete();
            return http.Response('', 201);
          }),
        ),
      );
      final notifications = FakeNotificationsController();
      final container = ProviderContainer(
        overrides: [
          tempTargetServiceProvider.overrideWithValue(service),
          notificationsControllerForegroundProvider.overrideWithValue(
            notifications,
          ),
        ],
      );
      addTearDown(container.dispose);
      final harness = FakeRuntimeHarness(container: container);
      final id = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Meal',
              plannedAt: clock.now().millisecondsSinceEpoch,
            ),
          );
      final offer = (await service.prepare(
        TempTargetNotificationEvent.meal(entityId: id),
      ))!;
      final restored =
          const NotificationEventFactory().fromPayload(
                offer.type,
                offer.toJson(),
              )
              as TempTargetNotificationEvent;
      expect(restored.requestId, offer.requestId);
      expect(restored.body, offer.body);
      final actionData =
          restored.toPayload()['action_data'] as Map<String, Object?>;
      final handler = NotificationResponseEventHandler();
      handler.handle(
        NotificationResponseEvent.tempTargetResponse(
          data: TempTargetResponseEvent.fromJson({
            ...actionData,
            'action': 'empty',
          }),
        ),
        harness.runtimeContext,
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      handler.handle(
        NotificationResponseEvent.tempTargetResponse(
          data: TempTargetResponseEvent.fromJson({
            ...actionData,
            'action': 'agree',
          }),
        ),
        harness.runtimeContext,
      );
      await sent.future;
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(notifications.shownEvents, isEmpty);
      handler.handle(
        NotificationResponseEvent.tempTargetResponse(
          data: TempTargetResponseEvent.fromJson({
            ...actionData,
            'action': 'agree',
          }),
        ),
        harness.runtimeContext,
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
    }),
  );

  test(
    'meal and activity prompts with the same entity ID do not replace each other',
    () {
      final meal = TempTargetNotificationEvent.meal(entityId: 1);
      final activity = TempTargetNotificationEvent.activity(entityId: 1);
      expect(meal.key.entityId, isNot(activity.key.entityId));
    },
  );
}
