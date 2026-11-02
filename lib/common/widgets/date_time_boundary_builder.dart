import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds when a future timestamp becomes current, and when the app resumes.
class DateTimeBoundaryBuilder extends StatefulWidget {
  const DateTimeBoundaryBuilder({
    super.key,
    required this.at,
    required this.builder,
  });

  final DateTime? at;
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<DateTimeBoundaryBuilder> createState() =>
      DateTimeBoundaryBuilderState();
}

class DateTimeBoundaryBuilderState extends State<DateTimeBoundaryBuilder>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(DateTimeBoundaryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.at != widget.at) _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (!_paused && mounted) setState(() {});
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final at = widget.at;
    final now = clock.now();
    if (_paused || at == null || !at.isAfter(now)) return;
    _timer = Timer(at.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, clock.now());
}
