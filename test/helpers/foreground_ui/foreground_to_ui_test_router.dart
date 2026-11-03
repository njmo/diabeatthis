import 'dart:convert';

import 'package:diabeatthis/common/events/task_event_payload.dart';
import 'package:diabeatthis/foreground/event/router/task_event_router.dart';

/// Replaces only the platform transport; serialization and both handlers remain real.
class ForegroundToUiTestRouter extends TaskEventRouter {
  final List<Map<String, dynamic>> messages = [];
  void Function(Map<String, dynamic>)? _receiver;

  void attach(void Function(Map<String, dynamic>) receiver) =>
      _receiver = receiver;
  void detach() => _receiver = null;

  @override
  void send(TaskEventPayload payload) {
    final wire =
        jsonDecode(jsonEncode(payload.toTaskEventJson()))
            as Map<String, dynamic>;
    messages.add(wire);
    _receiver?.call(wire);
  }
}
