import 'package:flutter/material.dart';

import '../../../../common/widgets/chart_color_label.dart';

/// A distribution of comparable quantities. Missing values never become zero.
class DayAmountBreakdown extends StatelessWidget {
  final List<({String label, String value, double? amount, Color color})>
  segments;
  const DayAmountBreakdown({super.key, required this.segments});

  @override
  Widget build(BuildContext context) {
    final complete = segments.every(
      (s) => s.amount != null && s.amount!.isFinite && s.amount! >= 0,
    );
    final total = complete
        ? segments.fold(0.0, (sum, s) => sum + s.amount!)
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 0) ...[
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: [
                    for (final segment in segments)
                      if (segment.amount! > 0)
                        Expanded(
                          flex: (segment.amount! / total * 100000)
                              .round()
                              .clamp(1, 100000),
                          child: ColoredBox(
                            color: segment.color,
                            child: const SizedBox.expand(),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final segment in segments)
              ChartColorLabel(
                color: segment.color,
                label: '${segment.label} · ${segment.value}',
              ),
          ],
        ),
      ],
    );
  }
}
