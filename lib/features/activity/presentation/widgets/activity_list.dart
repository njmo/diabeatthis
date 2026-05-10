import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/activity_log.dart';
import '../../data/providers/activity_provider.dart';

class ActivityList extends HookConsumerWidget {
  const ActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(getActivityLogsProvider);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        child: Column(
          children: [
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
                      return activity.whenOrNull(
                        view: (id, name, activityId, startedAt, endedAt) {
                          return Card(
                            child: ListTile(
                              title: Text(
                                name,
                                style: TextStyle(fontWeight: FontWeight.normal),
                              ),
                              subtitle: Text(
                                '${startedAt.toIso8601String()} - ${endedAt?.toIso8601String()}',
                              ),
                              onTap: () {
                                context.router.push(
                                  routes.ActivityLogRoute(activityLogId: id),
                                );
                              },
                            ),
                          );
                        },
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
      ),
    );
  }
}
