import 'package:flutter/material.dart';

/// A compact progress indicator; navigation stays with the validated form actions.
class FormStepHeader extends StatelessWidget {
  const FormStepHeader({
    super.key,
    required this.labels,
    required this.currentStep,
  });
  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              selected: currentStep == index,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: index <= currentStep
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    foregroundColor: index <= currentStep
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                    child: index < currentStep
                        ? const Icon(Icons.check, size: 16)
                        : Text('${index + 1}'),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
