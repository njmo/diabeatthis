import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/models/meal_details_data.dart';
import '../../data/models/activity_log_analysis_data.dart';
import '../../data/models/activity_log_details_data.dart';

class ActivityLogPageState {
  final ActivityLogDetailsData data;
  final AsyncValue<ActivityLogAnalysisData?> analysis;
  final List<MealLowTreatmentDetailsData> lowTreatments;
  final DateTime? selectedTimestamp;

  const ActivityLogPageState({
    required this.data,
    this.analysis = const AsyncData(null),
    this.lowTreatments = const [],
    this.selectedTimestamp,
  });

  ActivityLogPageState copyWith({
    ActivityLogDetailsData? data,
    AsyncValue<ActivityLogAnalysisData?>? analysis,
    List<MealLowTreatmentDetailsData>? lowTreatments,
    DateTime? selectedTimestamp,
    bool clearSelectedTimestamp = false,
  }) {
    return ActivityLogPageState(
      data: data ?? this.data,
      analysis: analysis ?? this.analysis,
      lowTreatments: lowTreatments ?? this.lowTreatments,
      selectedTimestamp: clearSelectedTimestamp
          ? null
          : selectedTimestamp ?? this.selectedTimestamp,
    );
  }
}
