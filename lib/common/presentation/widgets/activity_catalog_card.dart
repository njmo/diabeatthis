import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import 'activity_catalog_meta_pill.dart';

class ActivityCatalogCard extends StatelessWidget {
  final String name;
  final int percentagePre;
  final int percentagePost;
  final int? durationMinutes;
  final VoidCallback? onTap;

  const ActivityCatalogCard({
    super.key,
    required this.name,
    required this.percentagePre,
    required this.percentagePost,
    required this.durationMinutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ActivityCatalogMetaPill(
                    icon: Icons.timer,
                    text: _formatDuration(context, durationMinutes),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(BuildContext context, int? minutes) {
    if (minutes == null) {
      return context.lang.activityManualEnd;
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')} min';
  }
}
