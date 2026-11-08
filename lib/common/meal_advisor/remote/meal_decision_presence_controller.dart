import 'dart:async';

import 'package:flutter/widgets.dart';

/// Publishes lifecycle changes immediately, including when Flutter cannot render.
class MealDecisionPresenceController with WidgetsBindingObserver {
  MealDecisionPresenceController(this.send);

  final Future<void> Function(String stage, bool present) send;
  Future<void> queue = Future<void>.value();
  Timer? timer;
  bool enabled = false;
  bool disposed = false;
  String stage = 'context';

  void start() => WidgetsBinding.instance.addObserver(this);

  void update({required bool enabled, required String stage}) {
    if (disposed || this.enabled == enabled && this.stage == stage) return;
    final wasEnabled = this.enabled;
    this.enabled = enabled;
    this.stage = stage;
    timer?.cancel();
    if (enabled) {
      publish(
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
      );
      timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          publish(true);
        }
      });
    } else if (wasEnabled) {
      publish(false);
    }
  }

  void publish(bool present) {
    final currentStage = stage;
    queue = queue.then((_) async {
      try {
        await send(currentStage, present);
      } catch (_) {
        // Server-side presence expires if delivery fails.
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (enabled && !disposed) publish(state == AppLifecycleState.resumed);
  }

  void dispose() {
    if (disposed) return;
    disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    if (enabled) publish(false);
  }
}
