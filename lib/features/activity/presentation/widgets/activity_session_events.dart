import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/detail_content_section.dart';
import '../../../../core/domain/model/treatment_base.dart';
import 'activity_log_treatment_row.dart';

class ActivitySessionEvents extends StatelessWidget {
  final String title;
  final Iterable<Treatment> treatments;
  final DateTime start;
  final DateTime end;
  final bool includeStart;
  const ActivitySessionEvents({super.key, required this.title,
    required this.treatments, required this.start, required this.end, this.includeStart = true});
  @override
  Widget build(BuildContext context) {
    final events = treatments.where((event) {
      final time = event.createdAt;
      return event.isValid && time != null &&
        (includeStart ? !time.isBefore(start) : time.isAfter(start)) && !time.isAfter(end);
    }).toList()..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    return DetailContentSection(title: Text(title), initiallyExpanded: false,
      children: events.isEmpty ? [Text(context.lang.activityNoEvents)] :
        [for (final event in events) ActivityLogTreatmentRow(event)]);
  }
}
