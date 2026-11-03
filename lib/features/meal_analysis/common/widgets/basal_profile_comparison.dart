import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/record_value_bars.dart';

class BasalProfileComparison extends StatelessWidget {
  const BasalProfileComparison({super.key, required this.data});
  final InsulinBasalSummary data;
  @override
  Widget build(BuildContext context) {
    if (data.coveredDuration <= Duration.zero) {
      return const SizedBox.shrink();
    }
    final lang = context.lang;
    final number = NumberFormat('0.##', lang.localeName);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecordValueBars(
          values: [
            (
              label: lang.mealBasalProfile,
              value: data.profileUnits,
              formatted: '${number.format(data.profileUnits)} U',
              color: colors.secondary,
            ),
            (
              label: lang.dayBasalTitle,
              value: data.units,
              formatted: '${number.format(data.units)} U',
              color: colors.primary,
            ),
          ],
        ),
        Text(
          lang.mealBasalCoveredOnly,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
