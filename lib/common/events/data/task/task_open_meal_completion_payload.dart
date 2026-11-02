import '../../task_event_payload.dart';

class TaskOpenMealCompletionPayload with TaskEventPayload {
  final int mealId;

  const TaskOpenMealCompletionPayload({required this.mealId});

  factory TaskOpenMealCompletionPayload.fromJson(Map<String, dynamic> json) =>
      TaskOpenMealCompletionPayload(mealId: json['mealId'] as int);

  @override
  String get eventName => 'task_open_meal_completion';

  @override
  Map<String, dynamic> toJson() => {'mealId': mealId};
}
