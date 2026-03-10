import 'package:flutter/material.dart';

enum ConfidenceLevel { low, medium, high, certain }

extension ConfidenceLevelX on ConfidenceLevel {
  String get label => switch (this) {
    ConfidenceLevel.low => 'Niska',
    ConfidenceLevel.medium => 'Średnia',
    ConfidenceLevel.high => 'Wysoka',
    ConfidenceLevel.certain => 'Pewna',
  };

  /// Jeśli chcesz to zapisywać w bazie jako REAL 0..1.
  double toDouble01() => switch (this) {
    ConfidenceLevel.low => 0.25,
    ConfidenceLevel.medium => 0.50,
    ConfidenceLevel.high => 0.75,
    ConfidenceLevel.certain => 0.95,
  };

  /// Odwrotność: wczytaj REAL z bazy i przypnij do najbliższego stopnia.
  static ConfidenceLevel fromDouble01(double v) {
    final clamped = v.clamp(0.0, 1.0);
    // progi możesz dopasować pod siebie
    if (clamped < 0.375) return ConfidenceLevel.low;
    if (clamped < 0.625) return ConfidenceLevel.medium;
    if (clamped < 0.85) return ConfidenceLevel.high;
    return ConfidenceLevel.certain;
  }

  int toIndex() => index;
  static ConfidenceLevel fromIndex(int i) =>
      ConfidenceLevel.values[i.clamp(0, ConfidenceLevel.values.length - 1)];
}

class ConfidenceSlider extends StatelessWidget {
  const ConfidenceSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Pewność',
    this.showValueLabel = true,
  });

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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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
              .map((c) => Text(c.label,
              style: Theme.of(context).textTheme.labelSmall))
              .toList(),
        ),
      ],
    );
  }
}
