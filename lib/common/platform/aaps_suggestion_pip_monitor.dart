import 'dart:async';

import 'package:clock/clock.dart';

import '../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'aaps_suggestion_completion.dart';

class AapsSuggestionPipMonitor {
  AapsSuggestionPipMonitor({required this.dismiss});

  final Future<void> Function(String) dismiss;
  AapsSuggestionCompletion? _completion;
  String? _session;
  bool _ready = false;
  bool _confirmed = false;
  int _sequence = 0;

  String begin(AapsBolusSuggestionNotificationEvent event) {
    final now = clock.now();
    _session = '${now.microsecondsSinceEpoch}-${++_sequence}';
    _completion = AapsSuggestionCompletion(event: event, openedAt: now);
    _ready = false;
    _confirmed = false;
    return _session!;
  }

  void opened(String id, bool success) {
    if (id != _session) return;
    if (!success) {
      _session = null;
      _completion = null;
      return;
    }
    _ready = true;
    _dismissIfComplete();
  }

  void update(Map<String, dynamic> payload) {
    if (_completion == null) return;
    _confirmed = _completion!.update(payload);
    _dismissIfComplete();
  }

  void _dismissIfComplete() {
    if (!_ready || !_confirmed || _session == null) return;
    final id = _session!;
    _session = null;
    _completion = null;
    unawaited(dismiss(id));
  }
}
