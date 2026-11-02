import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Read-only comparison: fill is actual, the vertical marker is the plan.
class PlanActualMeter extends StatelessWidget {
  const PlanActualMeter({
    super.key,
    required this.planned,
    required this.actual,
    required this.semanticLabel,
  });
  final double planned;
  final double actual;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scale = math.max(math.max(planned, actual), 1.0);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 22,
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (actual / scale).clamp(0, 1),
                    minHeight: 10,
                    color: colors.primary,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
                Positioned(
                  left:
                      (planned / scale).clamp(0, 1) *
                      (constraints.maxWidth - 4),
                  child: Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
