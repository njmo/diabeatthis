import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';

extension ConfidenceLevelLabelX on ConfidenceLevel {
  String get label => switch (this) {
    ConfidenceLevel.low => lang.confidenceLow,
    ConfidenceLevel.medium => lang.confidenceMedium,
    ConfidenceLevel.high => lang.confidenceHigh,
    ConfidenceLevel.certain => lang.confidenceCertain,
  };
}

class ConfidenceSlider extends StatelessWidget {
  const ConfidenceSlider({
    super.key,
    required this.value,
    required this.onChanged,
    String? title,
    this.showValueLabel = true,
  }) : title = title ?? '';

  final ConfidenceLevel value;
  final ValueChanged<ConfidenceLevel> onChanged;

  final String title;
  final bool showValueLabel;

  @override
  Widget build(BuildContext context) {
    final sliderValue = value.toIndex().toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.isEmpty ? context.lang.confidenceTitle : title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (showValueLabel)
              Text(value.label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: sliderValue,
          min: 0,
          max: 3,
          divisions: 3, // 0,1,2,3 => 4 stopnie
          label: value.label,
          onChanged: (v) => onChanged(ConfidenceLevelX.fromIndex(v.round())),
        ),
        // Opcjonalnie: “legendka” pod suwakiem
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ConfidenceLevel.values
              .map(
                (c) => Text(
                  c.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
