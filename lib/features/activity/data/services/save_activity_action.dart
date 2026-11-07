import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/planning/planning_repository_provider.dart';
import '../drafts/activity_entry_action.dart';

Future<int?> saveActivityAction(
  WidgetRef ref,
  DashboardActivityAction action,
) => ref.read(planningRepositoryProvider).saveActivity(action);
