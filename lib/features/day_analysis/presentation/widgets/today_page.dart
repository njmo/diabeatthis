import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../data/providers/day_context_provider.dart';
import 'day_activity_card.dart';
import 'day_device_age_card.dart';
import 'day_glucose_card.dart';
import 'day_insulin_card.dart';
import 'day_meals_card.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dayContextProvider);
    final lang = context.lang;
    Future<void> refresh() async {
      ref.invalidate(dayContextProvider);
      try {
        await ref.read(dayContextProvider.future);
      } catch (_) {
        /* Rendered below. */
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lang.dayDraftTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: lang.dayRefresh,
                onPressed: state.isLoading ? null : refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(lang.daySourceUnavailable)),
            data: (day) => RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    lang.dayAsOf(
                      DateFormat('dd.MM.yyyy HH:mm').format(day.asOf),
                    ),
                  ),
                  if (day.failedSources.isNotEmpty)
                    Text(lang.dayPartialFailure),
                  DayGlucoseCard(
                    title: lang.dayGlucoseTitle,
                    summary: day.glucose,
                  ),
                  DayInsulinCard(
                    summary: day.boluses,
                    night: day.nightBoluses,
                    basal: day.basal,
                    nightBasal: day.nightBasal,
                  ),
                  DayMealsCard(day: day),
                  DayGlucoseCard(
                    title: lang.dayNightTitle,
                    summary: day.nightGlucose,
                  ),
                  Text(lang.dayNightNote),
                  DayActivityCard(activities: day.activities),
                  DayDeviceAgeCard(day: day),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
