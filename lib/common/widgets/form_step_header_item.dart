import 'package:flutter/material.dart';

import 'form_step_header_marker.dart';

class FormStepHeaderItem extends StatelessWidget {
  const FormStepHeaderItem({
    super.key,
    required this.label,
    required this.index,
    required this.currentStep,
    required this.count,
  });

  final String label;
  final int index;
  final int currentStep;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = index == currentStep;
    final colors = theme.colorScheme;
    return Semantics(
      selected: active,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: index == 0
            ? CrossAxisAlignment.start
            : index == count - 1
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.center,
        children: [
          FormStepHeaderMarker(index: index, currentStep: currentStep),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: index == 0
                ? TextAlign.start
                : index == count - 1
                ? TextAlign.end
                : TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style:
                (active
                        ? theme.textTheme.labelMedium
                        : theme.textTheme.labelSmall)
                    ?.copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      color: active
                          ? colors.onSurface
                          : colors.onSurfaceVariant,
                    ),
          ),
        ],
      ),
    );
  }
}
