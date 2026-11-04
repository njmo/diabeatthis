import 'package:flutter/material.dart';

import 'form_timeline_marker.dart';

/// Vertical progress gives long translated labels the whole available width.
class FormStepTimeline extends StatelessWidget {
  const FormStepTimeline({
    super.key,
    required this.labels,
    required this.currentStep,
  });
  final List<String> labels;
  final int currentStep;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < labels.length; index++)
          Semantics(
            selected: index == currentStep,
            child: Stack(
              children: [
                if (index < labels.length - 1)
                  Positioned(
                    left: 13,
                    top: 22,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 38,
                    top: index == currentStep ? 2 : 3,
                    bottom: index == currentStep ? 12 : 7,
                  ),
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: index == currentStep
                        ? theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          )
                        : theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
                Positioned(
                  left: index == currentStep ? 1 : 4,
                  top: index == currentStep ? 0 : 2,
                  child: FormTimelineMarker(
                    status: index < currentStep
                        ? FormTimelineStatus.completed
                        : index == currentStep
                        ? FormTimelineStatus.active
                        : FormTimelineStatus.pending,
                    number: index + 1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
