import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../event/model/foreground_event.dart';
import '../../runtime/event_dispatcher.dart';

class TaskContext {
  final ProviderContainer container;
  final EventDispatcher dispatcher;

  TaskContext({
    required this.container,
    required this.dispatcher,
  });

  void emit(ForegroundEvent event) {
    dispatcher.dispatch(event);
  }

  void log(String message) {
    print('[TaskContext] $message');
  }
}