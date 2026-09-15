import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';

class DayReviewStatusTile extends StatelessWidget {
  final String title;
  final AsyncValue<int> pending;
  final VoidCallback onTap;

  const DayReviewStatusTile({
    super.key,
    required this.title,
    required this.pending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => pending.when(
    skipLoadingOnRefresh: false,
    skipLoadingOnReload: false,
    loading: () => ListTile(
      title: Text(title),
      subtitle: Text(context.lang.dayReviewChecking),
      leading: const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
    error: (_, _) => ListTile(
      title: Text(title),
      subtitle: Text(context.lang.dayReviewUnavailable),
      leading: Icon(Icons.warning_amber, color: Colors.amber.shade800),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
    data: (count) => ListTile(
      title: Text(title),
      subtitle: Text(
        count == 0
            ? context.lang.dayReviewReviewed
            : context.lang.dayReviewPendingCount(count),
      ),
      leading: Icon(
        count == 0 ? Icons.check_circle_outline : Icons.warning_amber,
        color: count == 0
            ? Theme.of(context).colorScheme.primary
            : Colors.amber.shade800,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
