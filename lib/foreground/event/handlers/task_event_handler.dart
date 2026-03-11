import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/app_lifecycle_state_provider.dart';
import '../app_event.dart';

class TaskEventHandler {
  final ProviderContainer _container;

  TaskEventHandler(this._container);

  void handle(Map<String, dynamic> event) {
    final appEvent = AppEvent.fromJson(event);

    switch(appEvent)
    {
      case AppLifecycleChangeEvent(data: final data):
        final state = AppLifecycleState.values[data.state];
        _container.read(appLifecycleProvider.notifier).setState(state);
    }
  }
}
