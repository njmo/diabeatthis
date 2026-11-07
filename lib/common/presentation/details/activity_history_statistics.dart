import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/activity/data/models/activity_log_analysis_data.dart';
import '../../../features/activity/presentation/models/activity_log_page_state.dart';
import '../../../features/activity/presentation/widgets/activity_log_body.dart';
import 'activity_log_preview_controller.dart';

class ActivityHistoryStatistics extends HookWidget {
  const ActivityHistoryStatistics({
    super.key,
    required this.state,
    required this.data,
  });
  final ActivityLogPageState state;
  final ActivityLogAnalysisData data;

  @override
  Widget build(BuildContext context) {
    final selected = useState<DateTime?>(null);
    return ActivityLogBody.controlled(
      controller: CaregiverActivityLogPreviewController(
        state.copyWith(
          analysis: AsyncData(data),
          selectedTimestamp: selected.value,
        ),
        showAnalysis: true,
      ),
      onTimestampSelected: (time) => selected.value = time,
    );
  }
}
