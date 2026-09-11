import 'package:flutter/material.dart';

import '../history/glucose_window_summary.dart';
import '../theme/glucose_range_colors.dart';

class GlucoseRangeBar extends StatelessWidget {
  final GlucoseWindowSummary summary;
  final double height;
  const GlucoseRangeBar({super.key, required this.summary, this.height = 10});

  @override
  Widget build(BuildContext context) {
    final palette = GlucoseRangeColors(Theme.of(context).brightness);
    final durations = [
      summary.inRange,
      summary.aboveRange,
      summary.belowRange,
      summary.missing,
    ];
    final colors = [
      palette.inRange,
      palette.aboveRange,
      palette.belowRange,
      palette.missing,
    ];
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < durations.length; i++)
                if (durations[i] > Duration.zero)
                  Expanded(
                    flex: durations[i].inMilliseconds,
                    child: ColoredBox(
                      color: colors[i],
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            vertical: BorderSide(
                              color: Theme.of(context).colorScheme.surface,
                              width: .75,
                            ),
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
