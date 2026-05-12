import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../../core/domain/model/activity.dart';
import '../../data/providers/activity_provider.dart';

class ActivitySearch extends HookConsumerWidget {
  const ActivitySearch({
    super.key,
    this.autofocus = false,
    this.showSearchField = true,
  });

  final bool autofocus;
  final bool showSearchField;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final valuePicked = useState(-1);
    final activities = ref.watch(activitiesByQueryProvider(query.value));
    final draft = ref.watch(activityDraftProvider.notifier);

    return SizedBox(
      height: (MediaQuery.of(context).size.height * 0.36).clamp(260.0, 380.0),
      width: double.infinity,
      child: Column(
        children: [
          if (showSearchField) ...[
            StringFormField(
              label: 'Nazwa',
              value: '',
              onChanged: (value) => query.value = value,
              builder: (context, controller) {
                return TextFormField(
                  autofocus: autofocus,
                  controller: controller,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Nazwa',
                    counterText: '',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          activities.when(
            data: (data) {
              if (data.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Brak wyników'),
                );
              }
              return Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final activity = data[index];
                    final selected = valuePicked.value == index;
                    final theme = Theme.of(context);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: selected
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      elevation: selected ? 1 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.directions_run,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          _activityName(activity),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _activitySubtitle(activity),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () {
                          draft.overrideDraft(activity);
                          valuePicked.value = index;
                        },
                      ),
                    );
                  },
                ),
              );
            },
            error: (error, _) => Text(error.toString()),
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 16),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
    );
  }

  static String _activityName(Activity activity) {
    return activity.when(
      existing: (_, name, _, _, _) => name,
      draft: (name, _, _, _) => name,
      empty: () => '',
    );
  }

  static String _activitySubtitle(Activity activity) {
    final durationMinutes = activity.when(
      existing: (_, _, _, _, durationMinutes) => durationMinutes,
      draft: (_, _, _, durationMinutes) => durationMinutes,
      empty: () => null,
    );
    return _formatDuration(durationMinutes);
  }

  static String _formatDuration(int? minutes) {
    if (minutes == null) {
      return 'zakończenie ręczne';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')} min';
  }
}
