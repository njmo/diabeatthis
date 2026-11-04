import 'package:flutter/material.dart';

import '../../../../common/history/treatment_presentation.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../utils/activity_log_formatters.dart';

class ActivityLogTreatmentRow extends StatelessWidget {
  final Treatment treatment;

  const ActivityLogTreatmentRow(this.treatment, {super.key});

  @override
  Widget build(BuildContext context) {
    final createdAt = treatment.createdAt;
    final presentation = treatmentPresentation(context.lang, treatment);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(presentation.icon, color: presentation.color),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              createdAt == null
                  ? presentation.label
                  : '${formatActivityLogTime(createdAt)} • ${presentation.label}',
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              treatment.getParts(),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
