import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'family_plan_time_field.dart';

class FamilyActivityPlanForm extends StatefulWidget {
  const FamilyActivityPlanForm({
    super.key,
    required this.rows,
    required this.onSubmit,
    this.initial,
    this.moveOnly = false,
  });
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic>? initial;
  final bool moveOnly;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  @override
  State<FamilyActivityPlanForm> createState() => FamilyActivityPlanFormState();
}

class FamilyActivityPlanFormState extends State<FamilyActivityPlanForm> {
  late int? activityId = widget.initial?['activityId'] as int?;
  late DateTime start = DateTime.fromMillisecondsSinceEpoch(
    widget.initial?['startedAt'] as int? ??
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
  );
  late final duration = TextEditingController(
    text: '${widget.initial?['durationMinutes'] ?? 30}',
  );
  bool busy = false;
  bool failed = false;
  @override
  void dispose() {
    duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.moveOnly
              ? context.lang.familyPlanMove
              : context.lang.familyPlanActivity,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (!widget.moveOnly)
          DropdownButtonFormField<int>(
            initialValue: activityId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.lang.familyPlanActivity,
            ),
            items: [
              for (final row in widget.rows.where(
                (r) => r['kind'] == 'activities' && r['deleted'] != true,
              ))
                DropdownMenuItem(
                  value: (row['payload'] as Map)['id'] as int,
                  child: Text((row['payload'] as Map)['name'] as String),
                ),
            ],
            onChanged: busy ? null : (id) => setState(() => activityId = id),
          ),
        FamilyPlanTimeField(
          value: start,
          onChanged: (v) => setState(() => start = v),
          label: context.lang.familyPlanTime,
        ),
        if (!widget.moveOnly)
          TextField(
            controller: duration,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.lang.familyPlanMinutes,
            ),
          ),
        Text(context.lang.familyPlanPendingExplanation),
        if (failed) Text(context.lang.familyPlanFailed),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  final minutes = int.tryParse(duration.text) ?? 0;
                  if (!start.isAfter(DateTime.now()) ||
                      (!widget.moveOnly &&
                          (activityId == null ||
                              minutes < 1 ||
                              minutes > 1440))) {
                    setState(() => failed = true);
                    return;
                  }
                  setState(() {
                    busy = true;
                    failed = false;
                  });
                  try {
                    await widget.onSubmit(
                      widget.moveOnly
                          ? {'startedAt': start.millisecondsSinceEpoch}
                          : {
                              'activityId': activityId,
                              'startedAt': start.millisecondsSinceEpoch,
                              'durationMinutes': minutes,
                            },
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (_) {
                    if (mounted) setState(() => failed = true);
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: Text(context.lang.familyPlanSend),
        ),
      ],
    ),
  );
}
