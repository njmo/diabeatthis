import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../nutrition/confidence_level.dart';

extension ConfidenceLevelLabelX on ConfidenceLevel {
  String get label => labelFor(lang);

  String labelFor(AppLocalizations localizations) => switch (this) {
    ConfidenceLevel.low => localizations.confidenceLow,
    ConfidenceLevel.medium => localizations.confidenceMedium,
    ConfidenceLevel.high => localizations.confidenceHigh,
    ConfidenceLevel.certain => localizations.confidenceCertain,
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
            Expanded(
              child: Text(
                title.isEmpty ? context.lang.confidenceTitle : title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 8),
            if (showValueLabel)
              Flexible(
                child: Text(
                  value.label,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: sliderValue,
          min: 0,
          max: 3,
          divisions: 3,
          label: value.label,
          onChanged: (v) => onChanged(ConfidenceLevelX.fromIndex(v.round())),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: ConfidenceLevel.values
              .map(
                (c) => Expanded(
                  child: Text(
                    c.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
