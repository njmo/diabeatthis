import 'package:diabeatthis/app/event/task/task_event_handler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'foreground_to_ui_test_router.dart';

/// Connects a production UI event handler to the test's foreground transport.
class ForegroundTaskEventTestHost extends ConsumerStatefulWidget {
  const ForegroundTaskEventTestHost({
    required this.transport,
    required this.child,
    super.key,
  });

  final ForegroundToUiTestRouter transport;
  final Widget child;

  @override
  ConsumerState<ForegroundTaskEventTestHost> createState() =>
      ForegroundTaskEventTestHostState();
}

class ForegroundTaskEventTestHostState
    extends ConsumerState<ForegroundTaskEventTestHost> {
  late final TaskEventHandler handler;

  @override
  void initState() {
    super.initState();
    handler = TaskEventHandler(ref);
    widget.transport.attach(handler.handle);
  }

  @override
  void dispose() {
    widget.transport.detach();
    handler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
