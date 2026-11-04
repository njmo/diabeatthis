import 'package:flutter/material.dart';

/// Segment sizes follow value shares; zero totals have a neutral empty track.
class ProportionBar extends StatelessWidget {
  const ProportionBar({
    super.key,
    required this.values,
    required this.colors,
    required this.labels,
    this.height = 14,
    this.showPercentages = false,
  }) : assert(values.length == colors.length),
       assert(values.length == labels.length);

  final List<double> values;
  final List<Color> colors;
  final List<String> labels;
  final double height;
  final bool showPercentages;

  @override
  Widget build(BuildContext context) {
    final amounts = values
        .map((value) => value.isFinite && value > 0 ? value : 0.0)
        .toList();
    final total = amounts.fold(0.0, (sum, amount) => sum + amount);
    return Semantics(
      label: [
        for (var i = 0; i < amounts.length; i++)
          '${labels[i]}: ${amounts[i]} g · ${total > 0 ? (amounts[i] / total * 100).round() : 0}%',
      ].join(', '),
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: height,
            child: total <= 0
                ? ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < amounts.length; i++)
                        if (amounts[i] > 0)
                          Expanded(
                            flex: (amounts[i] / total * 10000).round().clamp(
                              1,
                              10000,
                            ),
                            child: ColoredBox(
                              color: colors[i],
                              child: !showPercentages
                                  ? null
                                  : LayoutBuilder(
                                      builder: (context, constraints) =>
                                          constraints.maxWidth < 40
                                          ? const SizedBox.shrink()
                                          : Center(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '${(amounts[i] / total * 100).round()}%',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            ThemeData.estimateBrightnessForColor(
                                                                  colors[i],
                                                                ) ==
                                                                Brightness.dark
                                                            ? Colors.white
                                                            : Colors.black,
                                                      ),
                                                ),
                                              ),
                                            ),
                                    ),
                            ),
                          ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
