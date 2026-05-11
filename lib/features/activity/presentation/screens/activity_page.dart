import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/domain/model/activity.dart';
import '../../data/providers/activity_provider.dart';
import '../widgets/activity_details_card.dart';
import '../widgets/activity_edit_form.dart';
import '../widgets/activity_log_list.dart';

@RoutePage()
class ActivityPage extends HookConsumerWidget {
  final int activityId;

  const ActivityPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = useState(false);
    final isSaving = useState(false);
    final activityState = ref.watch(getActivityByIdProvider(activityId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktywność'),
        actions: [
          IconButton(
            tooltip: isEditing.value ? 'Zamknij edycję' : 'Edytuj aktywność',
            icon: Icon(isEditing.value ? Icons.close : Icons.edit),
            onPressed: isSaving.value
                ? null
                : () {
                    isEditing.value = !isEditing.value;
                  },
          ),
        ],
      ),
      body: activityState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('error: $error')),
        data: (activity) {
          return activity?.whenOrNull(
                existing:
                    (id, name, percentagePre, percentagePost, durationMinutes) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: isEditing.value
                                ? ActivityEditForm(
                                    name: name,
                                    durationMinutes: durationMinutes,
                                    isSaving: isSaving.value,
                                    onCancel: () {
                                      isEditing.value = false;
                                    },
                                    onSave: (values) async {
                                      isSaving.value = true;
                                      try {
                                        await ref
                                            .read(
                                              activityControllerProvider
                                                  .notifier,
                                            )
                                            .updateActivity(
                                              Activity.existing(
                                                id: id,
                                                name: values.name,
                                                percentagePre: percentagePre,
                                                percentagePost: percentagePost,
                                                durationMinutes:
                                                    values.durationMinutes,
                                              ),
                                            );
                                        ref.invalidate(
                                          getActivityByIdProvider(activityId),
                                        );
                                        ref.invalidate(
                                          activityListPageProvider(0),
                                        );
                                        isEditing.value = false;
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Aktywność zapisana',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Nie udało się zapisać: $error',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        isSaving.value = false;
                                      }
                                    },
                                  )
                                : ActivityDetailsCard(
                                    name: name,
                                    percentagePre: percentagePre,
                                    percentagePost: percentagePost,
                                    durationMinutes: durationMinutes,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Text(
                              'Logi aktywności',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Expanded(child: ActivityLogList(activityId: id)),
                        ],
                      );
                    },
              ) ??
              const Center(child: Text('Nie znaleziono aktywności'));
        },
      ),
    );
  }
}
