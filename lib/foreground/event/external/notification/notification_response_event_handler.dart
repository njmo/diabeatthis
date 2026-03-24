import '../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../common/events/data/notification/meal_suggestion_response_event.dart';
import '../../../../common/events/data/notification/temp_target_response_event.dart';
import '../../../../core/logger/logger.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../task/base/runtime_context.dart';
import 'notification_response_event.dart';

class NotificationResponseEventHandler with Logging {
  NotificationResponseEventHandler();

  void handle(NotificationResponseEvent event, RuntimeContext context) {
    event.when(
      eatNowResponse: (data) => data.maybeWhen(
        eating: (mealId) => context.container.read(
          updateMealByIdProvider(data.mealId, 'eating'),
        ),
        orElse: () => context.emitEvent(data),
      ),
      tempTargetResponse: (TempTargetResponseEvent data) => context.emitEvent(data),
      mealSuggestionResponse: (MealSuggestionResponseEvent data) {
        logI('${data.runtimeType}');
        context.emitEvent(data);
      },
    );
  }
}
