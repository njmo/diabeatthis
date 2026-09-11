import 'package:flutter/material.dart';

/// A compact, tappable explanation next to the affected data.
class DataWarningIndicator extends StatelessWidget {
  final String message;
  const DataWarningIndicator({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final tooltipKey = GlobalKey<TooltipState>();
    return Tooltip(
      key: tooltipKey,
      message: message,
      triggerMode: TooltipTriggerMode.manual,
      showDuration: const Duration(seconds: 8),
      child: IconButton(
        onPressed: () => tooltipKey.currentState?.ensureTooltipVisible(),
        icon: const Icon(Icons.warning_amber_rounded),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.amber.shade300
            : const Color(0xFF8D6500),
      ),
    );
  }
}
