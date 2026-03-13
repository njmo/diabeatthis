import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/events/data/notification/eat_now_response_event.dart';
import '../../../../features/meals/data/providers/meal_database_provider.dart';
import '../../../runtime/event_dispatcher.dart';
import 'notification_response_event.dart';

class NotificationResponseEventHandler {
  final ProviderContainer _container;
  final EventDispatcher _dispatcher;

  NotificationResponseEventHandler(this._container, this._dispatcher);

  void handle(NotificationResponseEvent event) {
    event.when(
      eatNowResponse: (data) => data.maybeWhen(
        eating: (mealId) =>
            _container.read(updateMealByIdProvider(data.mealId, 'eating')),
        orElse: () => _dispatcher.dispatch(data),
      ),
    );
  }
}
