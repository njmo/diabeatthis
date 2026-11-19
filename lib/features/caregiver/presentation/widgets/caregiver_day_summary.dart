import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/l10n/language.dart';
import '../../data/caregiver_day_context_provider.dart';
import 'day_presentations/caregiver_day_timeline_view.dart';

class CaregiverDaySummary extends ConsumerWidget {
  const CaregiverDaySummary({
    super.key,
    required this.date,
    this.owner,
    this.source,
    this.revision = 0,
  });
  final DateTime date;
  final String? owner;
  final String? source;
  final int revision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(googleAccountProvider);
    if (account.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final uid = account.asData?.value?.uid;
    if (account.hasError || uid == null) {
      return Text(context.lang.familyGoogleRequired);
    }
    final provider = caregiverDayContextProvider((
      date: date,
      uid: uid,
      owner: owner,
      source: source,
      revision: revision,
    ));
    final state = ref.watch(provider);
    void refresh() => ref.invalidate(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        state.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, _) => Column(
            children: [
              Text(context.lang.daySourceUnavailable),
              IconButton(
                tooltip: context.lang.dayRefresh,
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
              ),
              TextButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
                label: Text(context.lang.commonRetry),
              ),
            ],
          ),
          data: (day) => CaregiverDayTimelineView(day: day),
        ),
      ],
    );
  }
}
