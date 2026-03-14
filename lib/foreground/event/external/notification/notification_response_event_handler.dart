import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../runtime/workflow_scheduler.dart';
import 'notification_response_event.dart';

class NotificationResponseEventHandler {
  final ProviderContainer _container;
  final WorkflowScheduler _workflowScheduler;

  NotificationResponseEventHandler(this._container, this._workflowScheduler);

  void handle(NotificationResponseEvent event) {
    event.when(
      eatNowResponse: (data) => data.maybeWhen(
        eating: (mealId) =>
            _container.read(updateMealByIdProvider(data.mealId, 'eating')),
        orElse: () => _workflowScheduler.emitEvent(data),
      ),
    );
  }
}
