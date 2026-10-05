import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/logger/logger.dart';
import '../widgets/low_treatment_sheet.dart';

/// Owns notification-triggered opening for the lifetime of the application UI.
class LowTreatmentSheetLauncher with Logging {
  LowTreatmentSheetLauncher({
    required this.getContext,
    Future<void> Function(BuildContext)? openSheet,
  }) : openSheet =
           openSheet ??
           ((context) async {
             await showLowTreatmentSheet(context);
           });

  final BuildContext? Function() getContext;
  final Future<void> Function(BuildContext) openSheet;
  Timer? _retry;
  bool _pending = false;
  bool _scheduled = false;
  bool _open = false;
  bool _disposed = false;
  int _attempts = 0;

  void requestOpen() {
    if (_disposed || _open) return;
    _pending = true;
    _attempts = 0;
    _schedule();
  }

  void retryPending() {
    if (_disposed) return;
    _attempts = 0;
    _schedule();
  }

  void dispose() {
    _disposed = true;
    _pending = false;
    _retry?.cancel();
    _retry = null;
  }

  void _schedule() {
    if (_disposed || !_pending || _scheduled || _open) return;
    _retry?.cancel();
    _retry = null;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || !_pending || _open) return;
      final context = getContext();
      if (context != null && context.mounted) {
        _pending = false;
        _attempts = 0;
        _open = true;
        unawaited(_show(context));
      } else if (++_attempts < 50) {
        _retry = Timer(const Duration(milliseconds: 100), _schedule);
      } else {
        logW('Low treatment opening remains pending until the UI resumes');
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _show(BuildContext context) async {
    try {
      await openSheet(context);
    } catch (error, stackTrace) {
      logE(
        'Could not open low treatment sheet',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _open = false;
    }
  }
}
