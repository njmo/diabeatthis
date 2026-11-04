import 'package:flutter/material.dart';

class FormStepHeaderMarker extends StatelessWidget {
  const FormStepHeaderMarker({
    super.key,
    required this.index,
    required this.currentStep,
  });

  final int index;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reached = index <= currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? colors.primary : colors.surfaceContainerLow,
        border: Border.all(color: reached ? colors.primary : colors.outline),
        boxShadow: index == currentStep
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .2),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: index < currentStep
          ? Icon(Icons.check, size: 16, color: colors.onPrimary)
          : Text(
              '${index + 1}',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: reached ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
    );
  }
}
