import '../../../features/activity/presentation/models/activity_log_page_state.dart';

abstract interface class ActivityLogPreviewController {
  ActivityLogPageState get state;
  bool get showAnalysis;
  bool get showRecordedSettings;
  bool get canUseLocalActions;
  void Function()? get onOpenActivity;
}

class PatientActivityLogPreviewController
    implements ActivityLogPreviewController {
  const PatientActivityLogPreviewController(this.state);
  @override
  final ActivityLogPageState state;
  @override
  bool get showAnalysis => true;
  @override
  bool get showRecordedSettings => true;
  @override
  bool get canUseLocalActions => true;
  @override
  void Function()? get onOpenActivity => null;
}

class CaregiverActivityLogPreviewController
    implements ActivityLogPreviewController {
  const CaregiverActivityLogPreviewController(
    this.state, {
    this.showAnalysis = false,
    this.onOpenActivity,
  });
  @override
  final ActivityLogPageState state;
  @override
  final bool showAnalysis;
  // Historic dose settings and planned duration are not in the log projection.
  @override
  bool get showRecordedSettings => false;
  @override
  bool get canUseLocalActions => false;
  @override
  final void Function()? onOpenActivity;
}
