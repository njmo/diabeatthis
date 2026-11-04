import 'package:flutter/material.dart';

import 'form_step_header_item.dart';

/// Connected progress markers; navigation stays with validated form actions.
class FormStepHeader extends StatelessWidget {
  const FormStepHeader({
    super.key,
    required this.labels,
    required this.currentStep,
    this.labelsBelowMarkers = true,
  });

  final List<String> labels;
  final int currentStep;
  final bool labelsBelowMarkers;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        if (labels.length > 1)
          Positioned(
            top: 13,
            left: 14,
            right: 14,
            child: Container(
              height: 1.5,
              color: colors.outlineVariant,
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: (currentStep / (labels.length - 1)).clamp(
                  0.0,
                  1.0,
                ),
                child: ColoredBox(color: colors.primary),
              ),
            ),
          ),
        Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: FormStepHeaderItem(
                  label: labels[index],
                  index: index,
                  currentStep: currentStep,
                  count: labels.length,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
