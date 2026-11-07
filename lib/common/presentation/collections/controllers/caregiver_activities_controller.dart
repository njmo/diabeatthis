import '../../../../core/domain/model/activity.dart';
import '../models/collection_state.dart';
import 'activities_controller.dart';

class CaregiverActivitiesController implements ActivitiesController {
  CaregiverActivitiesController({
    required List<Map<String, dynamic>> rows,
    required this.open,
    required this.onRetry,
    bool loading = false,
    bool failed = false,
  }) : state = CollectionState(
         items:
             rows
                 .where(
                   (r) => r['kind'] == 'activities' && r['deleted'] != true,
                 )
                 .map((r) {
                   final p = r['payload'] as Map;
                   return Activity(
                     id: p['id'] as int,
                     name: p['name'] as String,
                     percentagePre: p['percentage_pre'] as int? ?? 0,
                     percentagePost: p['percentage_post'] as int? ?? 0,
                     durationMinutes: p['duration_minutes'] as int?,
                   );
                 })
                 .toList()
               ..sort((a, b) => a.name.compareTo(b.name)),
         loading: loading,
         failed: failed,
       );
  @override
  final CollectionState<Activity> state;
  @override
  final void Function(Activity)? open;
  final void Function() onRetry;
  @override
  void retry() => onRetry();
  @override
  void loadMore() {}
}
