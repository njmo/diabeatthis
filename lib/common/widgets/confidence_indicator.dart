import 'package:flutter/material.dart';

import '../nutrition/confidence_level.dart';

class ConfidenceIndicator extends StatelessWidget {
  const ConfidenceIndicator({
    super.key,
    required this.value,
    required this.title,
    required this.levelLabel,
  });

  final double value;
  final String title;
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final level = ConfidenceLevelX.fromDouble01(value);
    final color = switch (level) {
      ConfidenceLevel.low => dark ? Colors.red.shade300 : Colors.red.shade700,
      ConfidenceLevel.medium =>
        dark ? Colors.amber.shade300 : Colors.amber.shade800,
      ConfidenceLevel.high || ConfidenceLevel.certain =>
        dark ? Colors.green.shade300 : Colors.green.shade700,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.bodySmall)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  levelLabel,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
            semanticsLabel: '$title: $levelLabel',
          ),
        ],
      ),
    );
  }
}
