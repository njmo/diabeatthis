import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/presentation/collections/controllers/activities_controller.dart';
import '../../../../common/presentation/collections/models/collection_state.dart';
import '../../../../common/presentation/collections/views/activities_view.dart';
import '../../data/providers/activity_provider.dart';

class ActivityList extends HookConsumerWidget {
  const ActivityList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = useState(activityListPageSize);
    final source = ref.watch(activityListStreamProvider);
    final all = source.value ?? const [];
    return SafeArea(
      bottom: false,
      top: false,
      child: ActivitiesView(
        controller: PatientActivitiesController(
          state: CollectionState(
            items: all.take(limit.value).toList(),
            loading: source.isLoading,
            failed: source.hasError,
            hasMore: all.length > limit.value,
          ),
          open: (item) =>
              context.router.push(routes.ActivityRoute(activityId: item.id)),
          onLoadMore: () {
            if (all.length > limit.value) limit.value += activityListPageSize;
          },
          onRetry: () => ref.invalidate(activityListStreamProvider),
        ),
      ),
    );
  }
}
