import 'package:flutter/material.dart';

/// A static delay/delivery timeline, not a progress indicator.
class DurationScheduleBar extends StatelessWidget {
  const DurationScheduleBar({
    super.key,
    required this.delay,
    required this.duration,
    required this.label,
  });
  final Duration delay;
  final Duration duration;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (delay.isNegative || duration <= Duration.zero) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 12,
          child: Row(
            children: [
              if (delay > Duration.zero)
                Expanded(
                  flex: delay.inSeconds,
                  child: ColoredBox(
                    color: colors.outlineVariant,
                    child: const SizedBox.expand(),
                  ),
                ),
              Expanded(
                flex: duration.inSeconds,
                child: ColoredBox(
                  color: colors.primary,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
