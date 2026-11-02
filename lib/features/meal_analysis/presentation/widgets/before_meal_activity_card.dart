import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/history_link_card.dart';
import '../../../../common/widgets/summary_detail_card.dart';
import '../../domain/models/before_meal_context.dart';

class BeforeMealActivityCard extends StatelessWidget {
  const BeforeMealActivityCard({super.key, required this.data});
  final BeforeMealContext data;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final activity = data.recentPrecedingActivity;
    String time(DateTime at) =>
        DateFormat('HH:mm', lang.localeName).format(at.toLocal());
    return SummaryDetailCard(
      title: lang.beforeMealRecentActivity,
      icon: Icons.directions_run_rounded,
      child: data.activities == null
          ? Text(lang.beforeMealUnavailable)
          : activity == null
          ? Text(lang.beforeMealNoRecentActivity)
          : HistoryLinkCard(
              title: activity.name,
              subtitle:
                  '${time(activity.startedAt)} · ${activity.endedAt == null ? lang.beforeMealOngoing : '${lang.beforeMealEnded} ${time(activity.endedAt!)}'}',
              icon: Icons.directions_run_rounded,
              onTap: () => context.router.push(
                ActivityLogRoute(activityLogId: activity.logId),
              ),
            ),
    );
  }
}
