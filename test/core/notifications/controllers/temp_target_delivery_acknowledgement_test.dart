import 'package:clock/clock.dart';
import 'package:diabeatthis/app/providers/app_lifecycle_state_provider.dart';
import 'package:diabeatthis/common/temporary_targets/temp_target_operation.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_operation_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/temp_target_service.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    hide TempTargetOperation;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/base/notifications_controller.dart';
import 'package:diabeatthis/core/notifications/controllers/notifications_controller_impl.dart';
import 'package:diabeatthis/core/notifications/domain/events/temp_target_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/providers/local_notifications_plugin_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late DatabaseImpl db;
  late SharedPreferences preferences;
  late TempTargetOperationRepository operations;
  late TempTargetService service;
  late RecordingTargetNotificationController inAppNotifications;
  late ProviderContainer container;
  late NotificationsControllerImpl notifications;
  late int logId;

  setUp(() async {
    now = DateTime(2026, 10, 29, 12);
    SharedPreferences.setMockInitialValues({
      nightscoutUrlKey: 'https://example.com',
      nightscoutTokenKey: 'write-token',
      nightscoutTempTargetsEnabledKey: true,
    });
    preferences = await SharedPreferences.getInstance();
    db = DatabaseImpl(NativeDatabase.memory());
    operations = TempTargetOperationRepository(db);
    service = TempTargetService(
      preferences: () async => preferences,
      database: () => db,
      writer: NightscoutTempTargetWriter(
        client: MockClient((_) async {
          throw StateError('Notification delivery must not call Nightscout');
        }),
      ),
    );
    final activityId = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Jujitsu',
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: const Value(60),
          ),
        );
    logId = await db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: activityId,
            startedAt: now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
        );
    inAppNotifications = RecordingTargetNotificationController();
    final controllerProvider = Provider(
      (ref) => NotificationsControllerImpl(ref, inAppNotifications),
    );
    container = ProviderContainer(
      overrides: [
        appLifecycleProvider.overrideWithValue(AppLifecycleState.resumed),
        sharedPrefsProvider.overrideWith((_) async => preferences),
        databaseProvider.overrideWithValue(db),
        tempTargetServiceProvider.overrideWithValue(service),
        localNotificationsPluginProvider.overrideWithValue(
          FlutterLocalNotificationsPlugin(),
        ),
      ],
    );
    notifications = container.read(controllerProvider);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'suppressed preparation leaves the request pending and recoverable after re-enabling uploads',
    () => withClock(Clock(() => now), () async {
      final offer = (await service.activityOffer(logId))!;
      await preferences.setBool(nightscoutTempTargetsEnabledKey, false);

      await notifications.show(offer, temporary: true);

      expect(inAppNotifications.shown, isEmpty);
      final operation = (await operations.get(offer.requestId!))!;
      expect(operation.status, TempTargetOperationStatus.pendingDelivery);
      expect(operation.deliveredAt, isNull);

      await preferences.setBool(nightscoutTempTargetsEnabledKey, true);
      now = now.add(const Duration(minutes: 1));
      final recovered = (await service.activityOffer(logId))!;
      expect(recovered.requestId, offer.requestId);
      await notifications.show(recovered, temporary: true);
      expect(inAppNotifications.shown, [recovered]);
      expect(
        (await operations.get(offer.requestId!))!.status,
        TempTargetOperationStatus.awaitingConsent,
      );
    }),
  );

  test(
    'successful display durably acknowledges delivery and prevents repeated offers',
    () => withClock(Clock(() => now), () async {
      final offer = (await service.activityOffer(logId))!;

      await notifications.show(offer, temporary: true);

      expect(inAppNotifications.shown, [offer]);
      final operation = (await operations.get(offer.requestId!))!;
      expect(operation.status, TempTargetOperationStatus.awaitingConsent);
      expect(operation.deliveredAt, now.toUtc());
      expect(await service.activityOffer(logId), isNull);
    }),
  );

  test(
    'a display failure retains the pending request and releases its retry lease',
    () => withClock(Clock(() => now), () async {
      final offer = (await service.activityOffer(logId))!;
      inAppNotifications.failShow = true;

      await expectLater(
        notifications.show(offer, temporary: true),
        throwsStateError,
      );

      final operation = (await operations.get(offer.requestId!))!;
      expect(operation.status, TempTargetOperationStatus.pendingDelivery);
      expect(operation.deliveredAt, isNull);
      final retry = (await service.activityOffer(logId))!;
      expect(retry.requestId, offer.requestId);

      inAppNotifications.failShow = false;
      await notifications.show(retry, temporary: true);
      expect(inAppNotifications.shown, [retry]);
      expect(
        (await operations.get(offer.requestId!))!.status,
        TempTargetOperationStatus.awaitingConsent,
      );
    }),
  );
}

class RecordingTargetNotificationController implements NotificationsController {
  final shown = <TempTargetNotificationEvent>[];
  var failShow = false;

  @override
  Future<void> show(NotificationEvent event) async {
    if (failShow) throw StateError('Could not display notification');
    shown.add(event as TempTargetNotificationEvent);
  }

  @override
  Future<void> init() async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<Iterable<int>> get pending async => [];

  @override
  Future<void> schedule(NotificationEvent event, Duration when) async {
    throw UnimplementedError();
  }
}
