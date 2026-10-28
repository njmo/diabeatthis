import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import '../l10n/language.dart';
import '../models/timeline_relation.dart';

class TimelineRelationPicker extends HookWidget {
  const TimelineRelationPicker({
    super.key,
    required this.occurredAt,
    required this.load,
  });
  final DateTime occurredAt;
  final Future<List<TimelineRelation>> Function(DateTime) load;

  @override
  Widget build(BuildContext context) {
    final day = useState(DateUtils.dateOnly(occurredAt));
    final retry = useState(0);
    final future = useMemoized(() => load(day.value), [day.value, retry.value]);
    final entries = useFuture(future);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Column(
          children: [
            ListTile(
              title: Text(context.lang.lowTreatmentRelationSelect),
              trailing: IconButton(
                tooltip: context.lang.commonCloseTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(
                DateFormat.yMd(context.lang.localeName).format(day.value),
              ),
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: day.value,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (selected != null && context.mounted) day.value = selected;
              },
            ),
            if (entries.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (entries.hasError)
              TextButton(
                onPressed: () => retry.value++,
                child: Text(context.lang.lowTreatmentRelationRetry),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    if (entries.data!.isEmpty)
                      ListTile(
                        title: Text(context.lang.lowTreatmentRelationEmpty),
                      ),
                    for (final entry in entries.data!)
                      ListTile(
                        leading: Icon(
                          entry.kind == TimelineRelationKind.activity
                              ? Icons.directions_run
                              : Icons.restaurant,
                        ),
                        title: Text(entry.name),
                        subtitle: Text(
                          DateFormat('dd.MM.yyyy HH:mm').format(entry.at),
                        ),
                        onTap: () => Navigator.of(context).pop(entry),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
