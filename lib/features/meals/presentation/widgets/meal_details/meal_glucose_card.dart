import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/show_detail_sheet.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../models/meal_page_state.dart';
import 'meal_glucose_details.dart';
import 'meal_history_download_button.dart';

class MealGlucoseCard extends StatelessWidget {
  final MealPageState state;
  const MealGlucoseCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final title = lang.mealCardObservation;
    return SummaryDetailCard(
      icon: Icons.show_chart_rounded,
      headerColor: Theme.of(context).colorScheme.primaryContainer,
      headerForeground: Theme.of(context).colorScheme.onPrimaryContainer,
      title: title,
      actionLabel: lang.mealPreviewPartialChart,
      onDetails: () => showDetailSheet(
        context: context,
        title: title,
        builder: (_) => MealGlucoseDetails(initialState: state),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lang.mealCardObservationHint),
          if (state.analysisError != null) Text(state.analysisError!),
          if (state.showHistoryDownload) ...[
            const SizedBox(height: 12),
            Text(lang.mealCardHistoryHint),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: MealHistoryDownloadButton(state: state, inline: true),
            ),
          ],
        ],
      ),
    );
  }
}
