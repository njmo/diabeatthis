import 'package:flutter/widgets.dart';

/// Reveals a newly expanded section after its final size is laid out.
/// The returned callback cancels a pending reveal if the selection changes.
VoidCallback scrollToWidgetAfterLayout(GlobalKey target) {
  var cancelled = false;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = target.currentContext;
    if (cancelled || context == null || !context.mounted) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  });
  return () => cancelled = true;
}
