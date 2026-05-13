import 'package:flutter/material.dart';

import '../../../../common/widgets/detail_section_card.dart';

class ActivityDetailsCard extends StatelessWidget {
  final String name;
  final int percentagePre;
  final int percentagePost;
  final int? durationMinutes;

  const ActivityDetailsCard({
    super.key,
    required this.name,
    required this.percentagePre,
    required this.percentagePost,
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return DetailSectionCard(
      title: name,
      children: [
        DetailInfoRow(
          icon: Icons.schedule,
          label: 'Wrażliwość 1h przed posiłkiem',
          value: '$percentagePre% mniej',
        ),
        DetailInfoRow(
          icon: Icons.sports_score,
          label: 'Wrażliwość po treningu',
          value: '$percentagePost% mniej',
        ),
        DetailInfoRow(
          icon: Icons.timer,
          label: 'Planowany czas',
          value: _formatDuration(durationMinutes),
        ),
      ],
    );
  }

  static String _formatDuration(int? minutes) {
    if (minutes == null) {
      return 'Do ręcznego zatrzymania';
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
