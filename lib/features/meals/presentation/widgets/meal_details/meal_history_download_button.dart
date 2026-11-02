import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/async_action_fab.dart';
import '../../controllers/meal_details_controller.dart';
import '../../models/meal_page_state.dart';

class MealHistoryDownloadButton extends ConsumerWidget {
  const MealHistoryDownloadButton({
    super.key,
    required this.state,
    this.inline = false,
  });

  final MealPageState state;
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> download() async {
      final messages = context.lang;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref
            .read(mealDetailsControllerProvider(state.details.meal.id).notifier)
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
    }

    if (inline) {
      return OutlinedButton.icon(
        onPressed: state.isDownloadingHistory ? null : download,
        icon: state.isDownloadingHistory
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_download_outlined),
        label: Text(
          state.isDownloadingHistory
              ? context.lang.mealDownloadingHistory
              : context.lang.mealCompleteHistoryFab,
        ),
      );
    }
    return AsyncActionFab(
      icon: Icons.cloud_download_outlined,
      label: context.lang.mealCompleteHistoryFab,
      isLoading: state.isDownloadingHistory,
      onPressed: download,
    );
  }
}
