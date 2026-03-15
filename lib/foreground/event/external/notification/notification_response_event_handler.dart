import '../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../task/base/runtime_context.dart';
import 'notification_response_event.dart';

class NotificationResponseEventHandler {

  NotificationResponseEventHandler();

  void handle(NotificationResponseEvent event, RuntimeContext context) {
    event.when(
      eatNowResponse: (data) => data.maybeWhen(
        eating: (mealId) =>
            context.container.read(updateMealByIdProvider(data.mealId, 'eating')),
        orElse: () => context.emitEvent(data),
      ),
    );
  }
}
