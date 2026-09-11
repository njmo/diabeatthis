import 'package:flutter/material.dart';

import 'day_low_treatment_review_section.dart';
import 'day_meal_review_section.dart';
import 'day_review_summary_card.dart';

/// Keeps both scroll targets mounted when the summary enters the viewport.
class DayReviewSection extends StatefulWidget {
  final DateTime date;
  const DayReviewSection({super.key, required this.date});

  @override
  State<DayReviewSection> createState() => DayReviewSectionState();
}

class DayReviewSectionState extends State<DayReviewSection> {
  final mealsKey = GlobalKey();
  final lowTreatmentsKey = GlobalKey();

  void scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DayReviewSummaryCard(
        date: widget.date,
        onMeals: () => scrollTo(mealsKey),
        onLowTreatments: () => scrollTo(lowTreatmentsKey),
      ),
      const SizedBox(height: 12),
      DayMealReviewSection(key: mealsKey, date: widget.date),
      DayLowTreatmentReviewSection(key: lowTreatmentsKey, date: widget.date),
    ],
  );
}
