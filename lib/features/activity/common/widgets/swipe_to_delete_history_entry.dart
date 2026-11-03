import 'package:flutter/material.dart';

import 'swipe_delete_background.dart';

/// Persistence streams remove the entry after confirmation, not the animation.
class SwipeToDeleteHistoryEntry extends StatelessWidget {
  const SwipeToDeleteHistoryEntry({
    super.key,
    required this.entryKey,
    this.enabled = true,
    required this.onDelete,
    required this.child,
  });

  final String entryKey;
  final bool enabled;
  final Future<void> Function() onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(entryKey),
    direction: enabled ? DismissDirection.endToStart : DismissDirection.none,
    background: const SwipeDeleteBackground(),
    confirmDismiss: (_) async {
      await onDelete();
      // A cancelled/failed deletion stays visible; successful writes remove the
      // row via the backing stream, including the containing empty day group.
      return false;
    },
    child: child,
  );
}
