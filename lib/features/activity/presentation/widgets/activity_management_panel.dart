import 'package:flutter/material.dart';
import '../../../../common/l10n/language.dart';
import 'activity_definition_sheet.dart';
import 'activity_list.dart';
import 'activity_upcoming_list.dart';

class ActivityManagementPanel extends StatelessWidget {
  const ActivityManagementPanel({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Column(
      children: [
        TabBar(
          tabs: [
            Tab(text: context.lang.managementActivitiesTab),
            Tab(text: context.lang.activityScheduleUpcoming),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: OutlinedButton.icon(
                      onPressed: () => showActivityDefinitionSheet(context),
                      icon: const Icon(Icons.add),
                      label: Text(context.lang.activityCreateTitle),
                    ),
                  ),
                  const Expanded(child: ActivityList()),
                ],
              ),
              const ActivityUpcomingList(),
            ],
          ),
        ),
      ],
    ),
  );
}
