import 'package:flutter/material.dart';

/// A compact, tappable explanation next to the affected data.
class DataWarningIndicator extends StatelessWidget {
  final String message;
  final bool compact;
  const DataWarningIndicator({
    super.key,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tooltipKey = GlobalKey<TooltipState>();
    return Tooltip(
      key: tooltipKey,
      message: message,
      triggerMode: TooltipTriggerMode.manual,
      showDuration: const Duration(seconds: 8),
      child: IconButton(
        padding: compact ? EdgeInsets.zero : null,
        constraints: compact
            ? const BoxConstraints.tightFor(width: 24, height: 24)
            : null,
        visualDensity: compact ? VisualDensity.compact : null,
        iconSize: compact ? 16 : null,
        onPressed: () => tooltipKey.currentState?.ensureTooltipVisible(),
        icon: const Icon(Icons.warning_amber_rounded),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.amber.shade300
            : const Color(0xFF8D6500),
      ),
    );
  }
}
