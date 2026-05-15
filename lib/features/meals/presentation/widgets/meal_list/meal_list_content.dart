import 'package:flutter/material.dart';

import '../../../../../core/domain/model/meal.dart' as domain;
import 'meal_list_item.dart';

class MealListContent extends StatelessWidget {
  final List<domain.Meal> meals;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<domain.Meal> onMealTap;
  final Future<bool> Function(domain.Meal meal) onMealDelete;

  const MealListContent({
    super.key,
    required this.meals,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.hasError,
    required this.onLoadMore,
    required this.onRetry,
    required this.onMealTap,
    required this.onMealDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (meals.isEmpty && isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (meals.isEmpty && hasError) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Spróbuj ponownie'),
        ),
      );
    }

    if (meals.isEmpty) {
      return const Center(child: Text('Brak posiłków'));
    }

    final bottomPadding = 24 + MediaQuery.viewPaddingOf(context).bottom;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final isUserScroll =
            notification is ScrollUpdateNotification ||
            notification is OverscrollNotification;
        if (isUserScroll && notification.metrics.extentAfter < 120) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
        cacheExtent: 0,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemCount: meals.length + 1,
        itemBuilder: (context, index) {
          if (index == meals.length) {
            return _buildTail();
          }

          final meal = meals[index];
          return MealListItem(
            meal: meal,
            onTap: () => onMealTap(meal),
            onDelete: () => onMealDelete(meal),
          );
        },
      ),
    );
  }

  Widget _buildTail() {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Spróbuj ponownie'),
        ),
      );
    }

    if (!hasMore) {
      return const SizedBox(height: 8);
    }

    return const SizedBox(height: 24);
  }
}
