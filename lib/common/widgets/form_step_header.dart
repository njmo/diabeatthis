import 'package:flutter/material.dart';

/// A compact progress indicator; navigation stays with the validated form actions.
class FormStepHeader extends StatelessWidget {
  const FormStepHeader({
    super.key,
    required this.labels,
    required this.currentStep,
    this.labelsBelowMarkers = false,
  });
  final List<String> labels;
  final int currentStep;
  final bool labelsBelowMarkers;

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
              child: Flex(
                direction: labelsBelowMarkers ? Axis.vertical : Axis.horizontal,
                mainAxisSize: MainAxisSize.min,
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
                  SizedBox(
                    width: labelsBelowMarkers ? 0 : 6,
                    height: labelsBelowMarkers ? 6 : 0,
                  ),
                  Flexible(
                    flex: labelsBelowMarkers ? 0 : 1,
                    fit: FlexFit.loose,
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      maxLines: labelsBelowMarkers ? 1 : null,
                      softWrap: !labelsBelowMarkers,
                      overflow: labelsBelowMarkers
                          ? TextOverflow.ellipsis
                          : null,
                      style: labelsBelowMarkers
                          ? (index == currentStep
                                    ? Theme.of(context).textTheme.labelMedium
                                    : Theme.of(context).textTheme.labelSmall)
                                ?.copyWith(
                                  fontWeight: index == currentStep
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                )
                          : Theme.of(context).textTheme.labelMedium,
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
