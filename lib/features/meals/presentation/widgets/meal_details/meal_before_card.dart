import 'package:flutter/material.dart';

import '../../../data/models/meal_start_context_data.dart';
import 'meal_before_context_section.dart';

class MealBeforeCard extends StatelessWidget {
  const MealBeforeCard({super.key, required this.data});
  final MealStartContextData data;

  @override
  Widget build(BuildContext context) =>
      MealBeforeContextSection(details: data.details, inline: true);
}
