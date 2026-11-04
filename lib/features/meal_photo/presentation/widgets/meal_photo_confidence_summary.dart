import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';

class MealPhotoConfidenceSummary extends StatelessWidget {
  const MealPhotoConfidenceSummary({
    super.key,
    required this.value,
    required this.title,
  });
  final double value;
  final String title;
  @override
  Widget build(BuildContext context) {
    final labels = [
      context.lang.confidenceLow,
      context.lang.confidenceMedium,
      context.lang.confidenceHigh,
      context.lang.confidenceCertain,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$title: ${labels[ConfidenceLevelX.fromDouble01(value).index]}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
