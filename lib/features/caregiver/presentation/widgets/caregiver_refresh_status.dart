import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../application/caregiver_ui_refresh_provider.dart';
import '../../data/caregiver_visible_state_provider.dart';

class CaregiverRefreshStatus extends ConsumerWidget {
  const CaregiverRefreshStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(caregiverVisibleStateProvider);
    final runner = ref.watch(caregiverUiRefreshProvider);
    final last = status.lastSuccess;
    final time = last == null
        ? null
        : MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(last));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.refreshing
                      ? context.lang.caregiverRefreshing
                      : context.lang.caregiverVisibleRefresh,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (time != null)
                  Text(
                    context.lang.caregiverLastRefresh(time),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (status.failed)
                  Text(
                    context.lang.caregiverRefreshFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.lang.caregiverRefreshNow,
            onPressed: status.refreshing || runner == null
                ? null
                : runner.refreshNow,
            icon: status.refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
