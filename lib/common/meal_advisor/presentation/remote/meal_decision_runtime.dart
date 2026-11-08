import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/providers/app_router_provider.dart';
import '../../../../core/data/provider/initial_configuration_provider.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import '../../../../features/dashboard/presentation/utils/show_meal_status_dialog.dart';
import '../../../app_mode/application_device_mode.dart';
import '../../../auth/google_authentication_providers.dart';
import '../../notifications/meal_decision_notification_intent.dart';
import '../../notifications/meal_decision_notifications_runtime.dart';
import '../../remote/accept_remote_meal_decision.dart';
import '../../remote/meal_decision_remote_controller.dart';
import 'caregiver_meal_decision_sheet.dart';
import 'meal_decision_presentation_registry.dart';

/// UI lifecycle/push routing only; caregivers never need the patient foreground service.
class MealDecisionRuntime extends ConsumerStatefulWidget {
  const MealDecisionRuntime({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<MealDecisionRuntime> createState() =>
      MealDecisionRuntimeState();
}

class MealDecisionRuntimeState extends ConsumerState<MealDecisionRuntime>
    with WidgetsBindingObserver {
  StreamSubscription<void>? intentSubscription;
  StreamSubscription<void>? presentationSubscription;
  Timer? receiptRetry;
  bool routing = false, replaying = false;
  bool drainAgain = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    presentationSubscription = MealDecisionPresentationRegistry.changes.stream
        .listen((_) => unawaited(drain()));
    intentSubscription = MealDecisionNotificationIntentStore.changes.stream
        .listen((_) => unawaited(drain()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(drain()));
    receiptRetry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(replayReceipts());
      }
    });
  }

  bool get configured =>
      Firebase.apps.isNotEmpty &&
      ref.read(initialConfigurationDoneProvider).asData?.value == true &&
      ref.read(googleAccountProvider).asData?.value != null;
  Future<void> replayReceipts() async {
    if (!mounted || !configured || replaying) return;
    replaying = true;
    try {
      await ref.read(reconcileMealDecisionReceiptsProvider)();
    } catch (_) {
      /* Durable receipts retry on resume. */
    } finally {
      replaying = false;
    }
  }

  Future<void> drain() async {
    if (!mounted || !configured) return;
    if (routing) {
      drainAgain = true;
      return;
    }
    final navContext = ref.read(appRouterProvider).navigatorKey.currentContext;
    if (navContext == null) return;
    routing = true;
    try {
      await replayReceipts();
      final store = MealDecisionNotificationIntentStore();
      for (final intent in await store.read()) {
        if (!mounted || !configured || !navContext.mounted) return;
        final uid = ref.read(googleAccountProvider).asData?.value?.uid;
        final controller = ref.read(
          mealDecisionRemoteControllerProvider.notifier,
        );
        await controller.refresh();
        if (!mounted ||
            ref.read(googleAccountProvider).asData?.value?.uid != uid) {
          return;
        }
        final inbox = ref.read(mealDecisionRemoteControllerProvider);
        if (inbox.failed) return;
        final request = inbox.byId(intent.requestId);
        if (request == null) {
          await store.remove(intent);
          continue;
        }
        final mode = await ref.read(applicationDeviceModeProvider.future);
        if (!mounted ||
            !configured ||
            ref.read(googleAccountProvider).asData?.value?.uid != uid) {
          return;
        }
        if (!navContext.mounted) return;
        if (mode == ApplicationDeviceMode.caregiver) {
          await showCaregiverMealDecisionRequest(
            navContext,
            request.id,
            action: intent.action,
            waitForClose: false,
          );
          await store.remove(intent);
        } else if (mode == ApplicationDeviceMode.patient &&
            request.ownerUid == uid) {
          if (MealDecisionPresentationRegistry.childMeals.contains(
            request.mealId,
          )) {
            await store.remove(intent);
            continue;
          }
          final stored = await ref
              .read(databaseProvider)
              .mealDao
              .getMealById(request.mealId);
          if (stored == null || !navContext.mounted) continue;
          if (stored.status != 'planned') {
            await store.remove(intent);
            continue;
          }
          final meal = stored.toDomain();
          final result = await showMealStatusDialog(
            context: navContext,
            meal: meal,
            startImmediately: true,
          );
          if (result != null && mounted && navContext.mounted) {
            await handleMealStatusDialogResult(
              context: navContext,
              ref: ref,
              meal: meal,
              result: result,
            );
          }
          await store.remove(intent);
        }
      }
    } catch (_) {
      // Keep the durable intent for the next resume/refresh if navigation failed.
    } finally {
      routing = false;
      if (drainAgain && mounted) {
        drainAgain = false;
        unawaited(drain());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && configured) {
      unawaited(
        ref.read(mealDecisionRemoteControllerProvider.notifier).refresh(),
      );
      unawaited(drain());
    }
  }

  @override
  void dispose() {
    receiptRetry?.cancel();
    unawaited(intentSubscription?.cancel());
    unawaited(presentationSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isNotEmpty) {
      ref.watch(mealDecisionNotificationsProvider);
    }
    if (Firebase.apps.isNotEmpty &&
        ref.watch(initialConfigurationDoneProvider).asData?.value == true) {
      ref.watch(mealDecisionRemoteControllerProvider);
      ref.listen(mealDecisionRemoteControllerProvider, (previous, next) {
        final shouldDrain =
            previous == null ||
            previous.loading ||
            previous.failed ||
            previous.requests.map((r) => r.id).join(',') !=
                next.requests.map((r) => r.id).join(',');
        if (shouldDrain && !next.loading && !next.failed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(replayReceipts());
              unawaited(drain());
            }
          });
        }
      });
    }
    return widget.child;
  }
}
