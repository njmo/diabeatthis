import 'package:flutter/material.dart';

import '../../../../common/presentation/widgets/activity_upcoming_sessions_button.dart';
import 'activity_upcoming_list.dart';

class ActivityUpcomingButton extends StatelessWidget {
  const ActivityUpcomingButton({super.key});
  @override
  Widget build(BuildContext context) => ActivityUpcomingSessionsButton(
    contentBuilder: (_) => const ActivityUpcomingList(),
  );
}
