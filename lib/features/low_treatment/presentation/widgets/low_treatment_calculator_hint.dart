import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/status_info_card.dart';

class LowTreatmentCalculatorHint extends StatelessWidget {
  const LowTreatmentCalculatorHint({super.key, required this.carbs});
  final num carbs;

  @override
  Widget build(BuildContext context) => carbs > 10
      ? StatusInfoCard(
          icon: Icons.calculate_outlined,
          title: context.lang.lowTreatmentConsiderCalculator,
        )
      : const SizedBox.shrink();
}
