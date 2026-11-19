import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../features/meals/presentation/widgets/meal_list/meal_card.dart';
import '../../../../features/meals/presentation/widgets/meal_list/meal_list_item.dart';
import '../../../history/history_day_group.dart';
import '../../../l10n/language.dart';
import '../../../widgets/history_day_section.dart';
import '../controllers/meals_controller.dart';

class MealListContent extends StatelessWidget {
  final List<domain.Meal> meals;
  final List<Widget> header;
  final String? Function(BuildContext, domain.Meal)? statusLabelFor;
  final VoidCallback? Function(domain.Meal)? retryFor;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool hasError;
  final VoidCallback onLoadMore;
  final VoidCallback onRetry;
  final ValueChanged<domain.Meal> onMealTap;
  final Future<bool> Function(domain.Meal meal)? onMealDelete;

  const MealListContent({
    super.key,
    required this.meals,
    this.header = const [],
    this.statusLabelFor,
    this.retryFor,
    required this.isInitialLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.hasError,
    required this.onLoadMore,
    required this.onRetry,
    required this.onMealTap,
    required this.onMealDelete,
  });

  MealListContent.controlled({
    super.key,
    required MealsController controller,
    this.header = const [],
    this.statusLabelFor,
    this.retryFor,
  }) : meals = controller.state.items,
       isInitialLoading = controller.state.loading,
       isLoadingMore = controller.state.loadingMore,
       hasMore = controller.state.hasMore,
       hasError = controller.state.failed,
       onLoadMore = controller.loadMore,
       onRetry = controller.retry,
       onMealTap = controller.open ?? ((_) {}),
       onMealDelete = controller.delete;

  @override
  Widget build(BuildContext context) {
    if (header.isEmpty && meals.isEmpty && isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (header.isEmpty && meals.isEmpty && hasError) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.lang.commonRetry),
        ),
      );
    }

    if (header.isEmpty && meals.isEmpty) {
      return Center(child: Text(context.lang.mealEmptyList));
    }

    final groups = groupHistoryByDay(meals, (meal) => meal.scheduleDate);
    final bottomPadding = 112 + MediaQuery.paddingOf(context).bottom;

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
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemCount: header.length + groups.length + 1,
        itemBuilder: (context, index) {
          if (index < header.length) return header[index];
          index -= header.length;
          if (index == groups.length) {
            return _buildTail(context);
          }

          final group = groups[index];
          return HistoryDaySection(
            key: ValueKey(group.date),
            date: group.date,
            itemCount: group.items.length,
            itemBuilder: (context, mealIndex) {
              final meal = group.items[mealIndex];
              if (onMealDelete == null) {
                return MealCard(
                  meal: meal,
                  onTap: () => onMealTap(meal),
                  statusLabel: statusLabelFor?.call(context, meal),
                  onRetry: retryFor?.call(meal),
                );
              }
              return MealListItem(
                meal: meal,
                onTap: () => onMealTap(meal),
                onDelete: () => onMealDelete!(meal),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTail(BuildContext context) {
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
          label: Text(context.lang.commonRetry),
        ),
      );
    }

    if (!hasMore) {
      return const SizedBox(height: 8);
    }

    return const SizedBox(height: 24);
  }
}
