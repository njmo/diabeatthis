import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/meal.dart';
import '../../data/providers/meal_database_provider.dart';

class MealList extends HookConsumerWidget {
  const MealList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = useState<List<Meal>>(const []);
    final nextPage = useState(0);
    final isLoading = useState(false);
    final hasMore = useState(true);
    final error = useState<Object?>(null);

    Future<void> loadNextPage() async {
      if (isLoading.value || !hasMore.value) {
        return;
      }

      isLoading.value = true;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!context.mounted) return;

        final page = await ref.read(
          mealListPageProvider(nextPage.value).future,
        );
        if (!context.mounted) return;

        meals.value = [...meals.value, ...page];
        nextPage.value += 1;
        hasMore.value = page.length == mealListPageSize;
        error.value = null;
      } catch (e) {
        if (!context.mounted) return;
        error.value = e;
      } finally {
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    useEffect(() {
      loadNextPage();
      return null;
    }, const []);

    if (meals.value.isEmpty && isLoading.value) {
      return const SafeArea(
        top: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (meals.value.isEmpty && error.value != null) {
      return SafeArea(
        top: false,
        child: Center(
          child: TextButton.icon(
            onPressed: loadNextPage,
            icon: const Icon(Icons.refresh),
            label: const Text('Spróbuj ponownie'),
          ),
        ),
      );
    }

    if (meals.value.isEmpty) {
      return const SafeArea(
        top: false,
        child: Center(child: Text('Brak posiłków')),
      );
    }

    final bottomPadding = 24 + MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final isUserScroll =
              notification is ScrollUpdateNotification ||
              notification is OverscrollNotification;
          if (isUserScroll && notification.metrics.extentAfter < 120) {
            loadNextPage();
          }
          return false;
        },
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding),
          cacheExtent: 0,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemCount: meals.value.length + 1,
          itemBuilder: (context, index) {
            if (index == meals.value.length) {
              return _MealListTail(
                isLoading: isLoading.value,
                hasMore: hasMore.value,
                hasError: error.value != null,
                onRetry: loadNextPage,
              );
            }

            final meal = meals.value[index];
            return _MealCard(
              meal: meal,
              onTap: () =>
                  context.router.push(routes.MealRoute(mealId: meal.id)),
            );
          },
        ),
      ),
    );
  }
}

class _MealListTail extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final bool hasError;
  final VoidCallback onRetry;

  const _MealListTail({
    required this.isLoading,
    required this.hasMore,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
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
                    text: _formatDateTime(meal.plannedAt),
                  ),
                  _MetaPill(
                    icon: Icons.history,
                    text: _daysAgo(meal.plannedAt),
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
      case 'eaten-extra':
      case 'eaten-bolused':
        return 'Zjedzony';
      case 'skipped':
        return 'Pominięty';
      case 'waited-eating':
      case 'bolused-eating':
      case 'eating':
      case 'eating-extra':
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

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${_shortTime(dt)} ${_formatDate(dt)}';
  }

  static String _daysAgo(DateTime? dt) {
    if (dt == null) return '-';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(day).inDays;

    if (days == 0) return 'Dzisiaj';
    if (days == 1) return 'Wczoraj';
    if (days < 0) return 'Za ${-days} dni';
    return '$days dni temu';
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
