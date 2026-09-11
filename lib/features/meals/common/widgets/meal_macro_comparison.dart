import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/chart_color_label.dart';
import '../theme/analysis_chart_colors.dart';

/// Uses net carbohydrates and the same 4/4/9 energy conversion as meal matching.
class MealMacroComparison extends StatelessWidget {
  final double netCarbs;
  final double protein;
  final double fat;
  final bool showRatio;
  final bool showRatioLabel;

  const MealMacroComparison({
    super.key,
    required this.netCarbs,
    required this.protein,
    required this.fat,
    this.showRatio = false,
    this.showRatioLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.#', lang.localeName);
    final energy = [netCarbs * 4, protein * 4, fat * 9];
    final total = energy.fold(0.0, (a, b) => a + b);
    final valid =
        energy.every((v) => v.isFinite && v >= 0) &&
        total.isFinite &&
        total > 0;
    final palette = AnalysisChartColors(Theme.of(context).brightness);
    final colors = [palette.carbs, palette.protein, palette.fat];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            ChartColorLabel(
              color: colors[0],
              label: '${lang.similarMealNetCarbs} ${number.format(netCarbs)} g',
            ),
            ChartColorLabel(
              color: colors[1],
              label: '${lang.similarMealProtein} ${number.format(protein)} g',
            ),
            ChartColorLabel(
              color: colors[2],
              label: '${lang.similarMealFat} ${number.format(fat)} g',
            ),
          ],
        ),
        if (showRatio && valid) ...[
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (var i = 0; i < energy.length; i++)
                      if (energy[i] > 0)
                        Expanded(
                          flex: (energy[i] / total * 10000).round().clamp(
                            1,
                            10000,
                          ),
                          child: ColoredBox(
                            color: colors[i],
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.symmetric(
                                  vertical: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    width: 0.75,
                                  ),
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
          if (showRatioLabel) const SizedBox(height: 4),
          if (showRatioLabel)
            Text(
              lang.mealMacroEnergyRatio(
                number.format(energy[0] / total * 100),
                number.format(energy[1] / total * 100),
                number.format(energy[2] / total * 100),
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ],
    );
  }
}
