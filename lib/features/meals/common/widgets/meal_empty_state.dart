import 'package:flutter/material.dart';

/// Decorative artwork is never used to imply an outcome when history is missing.
class MealEmptyState extends StatelessWidget {
  final String message;
  const MealEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        Image.asset(
          'assets/images/meals/meal_history_empty.png',
          width: 160,
          height: 136,
          cacheWidth: 480,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
