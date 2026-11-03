import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/meal/calculator/calculator_instruction_event.dart';
import '../../../common/meal/calculator/meal_calculator_request_controller_provider.dart';
import '../base/notifications_controller.dart';
import '../controllers/foreground_task_notification_controller.dart';
import '../controllers/in_app_notifications_controller.dart';
import '../controllers/notifications_controller_impl.dart';

part 'notifications_controller_provider.g.dart';

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerUi(Ref ref) {
  final notificationsController = NotificationsControllerImpl(
    ref,
    InAppNotificationsController(),
  );

  return notificationsController;
}

@Riverpod(keepAlive: true)
NotificationsController notificationsControllerForeground(Ref ref) {
  final notificationsController = NotificationsControllerImpl(
    ref,
    ForegroundTaskNotificationController(ref),
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
