import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../../../low_treatment/presentation/widgets/recorded_low_treatment_card.dart';

class BeforeMealLowsCard extends StatelessWidget {
  const BeforeMealLowsCard({super.key, required this.treatments});
  final List<RecordedLowTreatment>? treatments;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return SummaryDetailCard(
      title: lang.beforeMealLows,
      icon: Icons.cake_outlined,
      child: treatments == null
          ? Text(lang.beforeMealUnavailable)
          : treatments!.isEmpty
          ? Text(lang.beforeMealNoLows)
          : Column(
              children: [
                for (final low in treatments!)
                  RecordedLowTreatmentCard(treatment: low),
              ],
            ),
    );
  }
}
