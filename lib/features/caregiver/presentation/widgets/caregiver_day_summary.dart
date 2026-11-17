import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
          data: (day) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.lang.dayAsOf(
                          DateFormat(
                            'dd.MM.yyyy HH:mm',
                            context.lang.localeName,
                          ).format(day.asOf),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      IconButton(
                        tooltip: context.lang.dayRefresh,
                        onPressed: state.isLoading ? null : refresh,
                        icon: const Icon(Icons.refresh, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                CaregiverDayTimelineView(day: day),
              ],
            );
          },
        ),
      ],
    );
  }
}
