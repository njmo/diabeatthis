import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'activity_upcoming_list.dart';

class ActivityUpcomingButton extends StatelessWidget {
  const ActivityUpcomingButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.event_available_outlined),
    label: Text(context.lang.dashboardUpcomingTitle),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(
            children: [
              Text(
                context.lang.dashboardUpcomingTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Expanded(child: ActivityUpcomingList()),
            ],
          ),
        ),
      ),
    ),
  );
}
