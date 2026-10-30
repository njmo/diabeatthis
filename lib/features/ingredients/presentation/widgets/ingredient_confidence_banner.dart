import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/widgets/confidence_indicator.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';

class IngredientConfidenceBanner extends StatelessWidget {
  const IngredientConfidenceBanner({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => ConfidenceIndicator(
    value: value,
    title: context.lang.ingredientDataConfidence,
    levelLabel: ConfidenceLevelX.fromDouble01(value).label,
  );
}
