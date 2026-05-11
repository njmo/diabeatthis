import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/meal.dart';
import '../../data/providers/meal_database_provider.dart';

class MealList extends HookConsumerWidget {
  const MealList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagingController = useMemoized(
      () => PagingController<int, Meal>(
        getNextPageKey: _nextPageKey,
        fetchPage: (pageKey) => ref.read(mealListPageProvider(pageKey).future),
      ),
      const [],
    );
    useEffect(() => pagingController.dispose, [pagingController]);

    return SafeArea(
      top: false,
      child: PagingListener(
        controller: pagingController,
        builder: (context, state, fetchNextPage) {
          return PagedListView<int, Meal>.separated(
            state: state,
            fetchNextPage: fetchNextPage,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            cacheExtent: 0,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            builderDelegate: PagedChildBuilderDelegate<Meal>(
              invisibleItemsThreshold: 0,
              itemBuilder: (context, meal, index) {
                return _MealCard(
                  meal: meal,
                  onTap: () =>
                      context.router.push(routes.MealRoute(mealId: meal.id)),
                );
              },
              firstPageProgressIndicatorBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              newPageProgressIndicatorBuilder: (_) => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              noItemsFoundIndicatorBuilder: (_) =>
                  const Center(child: Text('Brak posiłków')),
              firstPageErrorIndicatorBuilder: (_) =>
                  const Center(child: Text('Nie udało się wczytać posiłków')),
              newPageErrorIndicatorBuilder: (_) => Center(
                child: TextButton.icon(
                  onPressed: fetchNextPage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Spróbuj ponownie'),
                ),
              ),
              noMoreItemsIndicatorBuilder: (_) => const SizedBox(height: 8),
            ),
          );
        },
      ),
    );
  }
}

int? _nextPageKey(PagingState<int, Meal> state) {
  final pages = state.pages;
  if (pages != null &&
      pages.isNotEmpty &&
      pages.last.length < mealListPageSize) {
    return null;
  }
  final keys = state.keys;
  return keys == null || keys.isEmpty ? 0 : keys.last + 1;
}

class _MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;

  const _MealCard({required this.meal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(meal.plannedAt),
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.access_time,
                    text: _shortTime(meal.plannedAt),
                  ),
                  _MetaPill(
                    icon: Icons.flag_outlined,
                    text: _toMealStatus(meal.status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _toMealStatus(String? status) {
    switch (status) {
      case 'eaten':
      case 'eaten-bolused':
        return 'Zjedzony';
      case 'skipped':
        return 'Pominięty';
      case 'waited-eating':
      case 'bolused-eating':
      case 'eating':
      case 'eating-then-bolus':
        return 'W trakcie jedzenia';
      case 'bolused-waiting':
        return 'Oczekuje';
      case 'summarized':
        return 'Podsumowany';
      default:
        return 'Zaplanowany';
    }
  }

  static String _shortTime(DateTime? dt) {
    if (dt == null) return '-';
    final t = TimeOfDay.fromDateTime(dt);
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day.$month.${dt.year}';
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
