import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/day/day_history_statistics.dart';
import '../../data/providers/day_context_provider.dart';
import '../../data/providers/day_meal_review_provider.dart';
import 'day_activity_card.dart';
import 'day_ai_button.dart';
import 'day_date_selector.dart';
import 'day_meals_card.dart';
import 'day_review_section.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key, this.onDateSelected, this.initialDate});
  final ValueChanged<DateTime?>? onDateSelected;
  final DateTime? initialDate;

  @override
  ConsumerState<TodayPage> createState() => TodayPageState();
}

class TodayPageState extends ConsumerState<TodayPage> {
  DateTime? selectedDate;
  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final provider = selectedDate == null
        ? dayContextProvider
        : dayContextForDateProvider(selectedDate);
    final state = ref.watch(provider);
    final today = DateUtils.dateOnly(clock.now().toLocal());
    final lang = context.lang;
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DayDateSelector(
            date: selectedDate ?? today,
            today: today,
            onSelected: (date) {
              setState(() => selectedDate = date);
              widget.onDateSelected?.call(date);
            },
            actions: [
              DayAiButton(date: selectedDate ?? today),
              IconButton(
                tooltip: lang.dayRefresh,
                onPressed: state.isLoading ? null : refresh,
                icon: const Icon(Icons.refresh, size: 20),
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
                key: ValueKey(day.start),
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ...dayHistoryStatisticCards(context, day),
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
