import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/family_chat/data/family_chat_database_provider.dart';
import '../../../common/family_chat/notifications/family_chat_push.dart';
import '../../../common/family_chat/notifications/family_chat_retry_guard.dart';
import '../../../common/meal/calculator/calculator_instruction_event.dart';
import '../../../common/meal/calculator/meal_calculator_request_controller_provider.dart';
import '../../domain/model/meal_status_flow.dart';
import '../../drift/providers/database_provider.dart';
import '../base/notifications_controller.dart';
import '../controllers/foreground_task_notification_controller.dart';
import '../controllers/in_app_notifications_controller.dart';
import '../controllers/notifications_controller_impl.dart';
import '../domain/events/family_chat_notification.dart';
import '../domain/events/finished_eating_event_notification.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_retry_policy.dart';
import '../in_app/in_app_notification_center.dart';
import 'local_notifications_controller_provider.dart';

part 'notifications_controller_provider.g.dart';

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerUi(Ref ref) {
  final notificationsController = NotificationsControllerImpl(
    ref,
    InAppNotificationsController(ref),
    localController: ref.watch(localNotificationsControllerProvider),
    onInboxChanged: () =>
        unawaited(ref.read(inAppNotificationCenterProvider.notifier).refresh()),
  );

  return notificationsController;
}

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerForeground(Ref ref) {
  final local = ref.watch(localNotificationsControllerProvider);
  final inApp = ForegroundTaskNotificationController(ref);
  final notificationsController = NotificationsControllerImpl(
    ref,
    inApp,
    localController: local,
    showSystemRetry: local.showRetry,
    showInAppRetry: inApp.showRetry,
    retryStillRelevant: (event) async {
      if (event is FamilyChatNotificationEvent &&
          isActionableFamilyTreatment(event)) {
        if (Firebase.apps.isEmpty) return false;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final familyId = event.payload['familyId'];
        final messageId = event.payload['messageId'];
        if (uid == null ||
            event.payload['uid'] != uid ||
            familyId is! String ||
            messageId is! String) {
          return false;
        }
        final relevant = await revalidateFamilyTreatmentRetry(event);
        if (relevant != true) return relevant;
        final confirmed = await ref
            .read(databaseProvider)
            .customSelect(
              'SELECT 1 FROM family_treatment_journal '
              'WHERE owner_uid=? AND family_id=? AND message_id=? '
              'AND (confirmed_at IS NOT NULL OR meal_id IS NOT NULL) LIMIT 1',
              variables: [
                Variable(uid),
                Variable(familyId),
                Variable(messageId),
              ],
            )
            .getSingleOrNull();
        return confirmed == null;
      }
      if (event is! FinishedEatingNotificationEvent) return true;
      final meal = await ref
          .read(databaseProvider)
          .mealDao
          .getMealById(event.mealId);
      return event.isAddOn
          ? meal?.status == 'eating-extra'
          : mealStatusesStartingEating.contains(meal?.status);
    },
    withAuthorizedChatRetry: (entry, event, deliver) async {
      if (Firebase.apps.isEmpty) return;
      await withAuthorizedFamilyChatRetry(
        db: ref.read(familyChatDatabaseProvider),
        currentUid: () => FirebaseAuth.instance.currentUser?.uid,
        entry: entry,
        event: event,
        deliver: deliver,
      );
    },
    // The service isolate only learns the UI lifecycle through messages, which
    // stop arriving when the UI process dies; confirm with the platform.
    isAppVisible: () => FlutterForegroundTask.isAppOnForeground,
    onInboxChanged: inApp.notifyInboxChanged,
    onShown: (event) async {
      final instruction = calculatorInstructionEvent(event);
      if (instruction == null ||
          (instruction.carbs == 0 && instruction.extendedCarbs == 0)) {
        return;
      }
      await ref
          .read(mealCalculatorRequestControllerProvider)
          .register(instruction);
    },
  );

  return notificationsController;
}

/// Delivery for work that runs without the app UI, such as push handlers and
/// notification responses in a headless container: system notifications,
/// still mirrored into the inbox. The app UI uses [notificationsControllerUi].
final notificationsControllerHeadlessProvider =
    Provider<NotificationsController>(
      (ref) => NotificationsControllerImpl(
        ref,
        const _NoInAppNotifications(),
        localController: ref.watch(localNotificationsControllerProvider),
        isAppVisible: () async => false,
      ),
    );

class _NoInAppNotifications implements NotificationsController {
  const _NoInAppNotifications();

  @override
  Future<void> init() async {}

  @override
  Future<void> show(NotificationEvent event) async {}

  @override
  Future<void> schedule(NotificationEvent event, Duration when) async {}

  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<Iterable<int>> get pending async => const [];
}
