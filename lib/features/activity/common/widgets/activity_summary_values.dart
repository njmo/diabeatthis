import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'activity_intensity_field.dart';

class ActivitySummaryValues extends StatelessWidget {
  const ActivitySummaryValues({
    super.key,
    this.intensity,
    this.notes,
    this.compact = false,
  });
  final String? intensity;
  final String? notes;
  final bool compact;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${compact ? context.lang.activityIntensityLabel : context.lang.activityPerceivedIntensity}: ${ActivityIntensityField.label(context.lang, intensity)}',
        style: compact ? Theme.of(context).textTheme.bodySmall : null,
      ),
      if (notes != null && notes!.trim().isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          '${context.lang.activityNotesLabel}: $notes',
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: compact ? Theme.of(context).textTheme.bodySmall : null,
        ),
      ],
    ],
  );
}
