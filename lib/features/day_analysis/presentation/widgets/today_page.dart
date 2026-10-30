import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../data/providers/day_context_provider.dart';
import '../../data/providers/day_meal_review_provider.dart';
import '../../data/providers/day_summary_provider.dart';
import 'day_activity_card.dart';
import 'day_ai_button.dart';
import 'day_date_selector.dart';
import 'day_device_age_card.dart';
import 'day_glucose_card.dart';
import 'day_insulin_card.dart';
import 'day_meals_card.dart';
import 'day_review_section.dart';
import 'day_summary_status.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => TodayPageState();
}

class TodayPageState extends ConsumerState<TodayPage> {
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    final provider = selectedDate == null
        ? dayContextProvider
        : dayContextForDateProvider(selectedDate);
    final state = ref.watch(provider);
    final today = DateUtils.dateOnly(clock.now().toLocal());
    final lang = context.lang;
    final accepted = ref.watch(
      acceptedDaySummaryProvider(selectedDate ?? today),
    );
    Future<void> refresh() async {
      ref.invalidate(provider);
      ref.invalidate(dayMealReviewProvider(selectedDate ?? today));
      ref.invalidate(dayMealCandidatesProvider(selectedDate ?? today));
      try {
        await ref.read(provider.future);
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
                  accepted.asData?.value != null
                      ? lang.dayAcceptedTitle
                      : selectedDate == null
                      ? lang.dayDraftTitle
                      : lang.dayHistoricalDraftTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              DayAiButton(date: selectedDate ?? today),
              const SizedBox(width: 4),
              IconButton(
                tooltip: lang.dayRefresh,
                onPressed: state.isLoading ? null : refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        DayDateSelector(
          date: selectedDate ?? today,
          today: today,
          onSelected: (date) => setState(() => selectedDate = date),
        ),
        Expanded(
          child: state.when(
            skipLoadingOnRefresh: false,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(lang.daySourceUnavailable)),
            data: (day) => RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                key: ValueKey(day.start),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    lang.dayAsOf(
                      DateFormat('dd.MM.yyyy HH:mm').format(day.asOf),
                    ),
                  ),
                  DaySummaryStatus(date: day.start),
                  DayDeviceAgeCard(day: day),
                  DayGlucoseCard(
                    title: lang.dayNightTitle,
                    summary: day.nightGlucose,
                    information: lang.dayNightNote,
                  ),

                  DayInsulinCard(
                    summary: day.nightBoluses,
                    basal: day.nightBasal,
                    isNight: true,
                  ),
                  DayGlucoseCard(
                    title: lang.dayGlucoseTitle,
                    summary: day.glucose,
                  ),
                  DayInsulinCard(summary: day.boluses, basal: day.basal),
                  DayMealsCard(day: day),
                  DayReviewSection(date: day.start),
                  DayActivityCard(activities: day.activities),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
