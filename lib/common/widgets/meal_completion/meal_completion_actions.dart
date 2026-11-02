import 'dart:math';

import 'package:flutter/material.dart';

class MealCompletionActions extends StatelessWidget {
  const MealCompletionActions({
    super.key,
    required this.primaryLabel,
    required this.primaryDescription,
    required this.secondaryLabel,
    required this.secondaryDescription,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final String primaryLabel;
  final String primaryDescription;
  final String secondaryLabel;
  final String secondaryDescription;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge;
    double labelWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final primary = Tooltip(
      message: primaryDescription,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          textStyle: textStyle,
        ),
        onPressed: onPrimaryPressed,
        child: Text(primaryLabel, textAlign: TextAlign.center),
      ),
    );
    final secondary = Tooltip(
      message: secondaryDescription,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          textStyle: textStyle,
        ),
        onPressed: onSecondaryPressed,
        child: Text(secondaryLabel, textAlign: TextAlign.center),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth - 8;
        final primaryFits = rowWidth * 0.8 >= labelWidth(primaryLabel) + 32;
        final secondaryFits =
            rowWidth * 0.2 >= max(48, labelWidth(secondaryLabel) + 8);
        if (primaryFits && secondaryFits) {
          return Row(
            children: [
              Expanded(flex: 4, child: primary),
              const SizedBox(width: 8),
              Expanded(child: secondary),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [primary, const SizedBox(height: 8), secondary],
        );
      },
    );
  }
}
