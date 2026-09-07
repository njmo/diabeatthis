import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/async_action_fab.dart';
import '../../controllers/meal_details_controller.dart';
import '../../models/meal_page_state.dart';

class MealHistoryDownloadButton extends ConsumerWidget {
  const MealHistoryDownloadButton({super.key, required this.state});

  final MealPageState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncActionFab(
      icon: Icons.cloud_download_outlined,
      isLoading: state.isDownloadingHistory,
      label: state.analysis?.hasHistoryData ?? false
          ? context.lang.mealCompleteHistoryFab
          : context.lang.mealDownloadHistoryFab,
      tooltip: state.isDownloadingHistory
          ? context.lang.mealDownloadingHistory
          : context.lang.mealDownloadHistory,
      onPressed: () async {
        final messages = context.lang;
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref
              .read(
                mealDetailsControllerProvider(state.details.meal.id).notifier,
              )
              .downloadHistory();
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text(messages.mealDownloadHistorySuccess)),
          );
        } catch (_) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text(messages.mealDownloadHistoryError)),
          );
        }
      },
    );
  }
}
