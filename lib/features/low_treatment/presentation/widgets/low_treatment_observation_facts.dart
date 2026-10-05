import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/history/stress_event_labels.dart';
import '../../../../common/l10n/language.dart';
import '../../domain/models/low_treatment_observation_context_data.dart';

class LowTreatmentObservationFacts extends StatelessWidget {
  const LowTreatmentObservationFacts({super.key, required this.data});

  final LowTreatmentObservationContextData data;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final activity = data.activityName;
    final activityAt = data.activityStartsAt;
    final stress = data.stressLevel;
    final stressAt = data.stressObservedAt;
    final labels = <String>[
      if (activity != null && activity.trim().isNotEmpty && activityAt != null)
        lang.lowTreatmentContextActivity(activity, _time(context, activityAt)),
      if (stress != null && stressAt != null)
        lang.lowTreatmentContextStress(
          stressLevelLabel(lang, stress),
          _time(context, stressAt),
        ),
    ];
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: labels.map((label) => Chip(label: Text(label))).toList(),
      ),
    );
  }

  String _time(BuildContext context, DateTime at) {
    final local = at.toLocal();
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    if (DateUtils.isSameDay(local, clock.now().toLocal())) return time;
    return '${DateFormat.Md(Localizations.localeOf(context).toLanguageTag()).format(local)} $time';
  }
}
