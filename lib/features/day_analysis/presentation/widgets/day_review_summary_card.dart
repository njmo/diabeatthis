import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/day_low_treatment_review_provider.dart';
import '../../data/providers/day_meal_review_provider.dart';
import 'day_review_status_tile.dart';

class DayReviewSummaryCard extends ConsumerWidget {
  final DateTime date;
  final VoidCallback onMeals;
  final VoidCallback onLowTreatments;

  const DayReviewSummaryCard({
    super.key,
    required this.date,
    required this.onMeals,
    required this.onLowTreatments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref
        .watch(dayMealReviewProvider(date))
        .whenData(
          (entries) => entries.where((entry) => entry.meal == null).length,
        );
    final lows = ref
        .watch(dayLowTreatmentReviewProvider(date))
        .whenData(
          (entries) => entries.where((entry) => entry.isPending).length,
        );
    final complete =
        !meals.isLoading &&
        !lows.isLoading &&
        !meals.hasError &&
        !lows.hasError &&
        meals.asData?.value == 0 &&
        lows.asData?.value == 0;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              complete ? 'Wszystkie wpisy sprawdzone' : 'Do uzupełnienia',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          DayReviewStatusTile(title: 'Posiłki', pending: meals, onTap: onMeals),
          DayReviewStatusTile(
            title: 'Dosłodzenia',
            pending: lows,
            onTap: onLowTreatments,
          ),
        ],
      ),
    );
  }
}
