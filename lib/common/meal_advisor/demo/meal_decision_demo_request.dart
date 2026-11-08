import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../meal_decision_preferences.dart';
import 'meal_decision_demo_answer.dart';
import 'meal_decision_demo_snapshot.dart';

enum MealDecisionDemoStage { context, decision }

enum MealDecisionDemoStatus { sending, waiting, answered, accepted, timedOut }

/// Immutable local UI state; deliberately separate from persisted meal state.
class MealDecisionDemoRequest {
  const MealDecisionDemoRequest({
    required this.id,
    required this.key,
    required this.mealName,
    required this.snapshot,
    required this.status,
    this.stage = MealDecisionDemoStage.context,
    this.caregiverPresent = false,
    this.timeoutFallback = MealDecisionTimeoutFallback.app,
    this.fallbackAdvice,
    this.mealId,
    this.childOwner,
    this.mirrorSource,
    this.claimExpiresAt,
    this.claimExpired = false,
    this.transferredFrom,
    this.transferredTo,
    this.claimedBy,
    this.claimedById,
    this.caregiverId,
    this.acceptedAdvice,
    this.answer,
    this.waitMinutes = 0,
    this.caregiverName,
    this.message = '',
    this.suggestMealTarget = false,
    this.deferredUntil,
  });
  final String id, key, mealName;
  final int? mealId;
  final String? childOwner, mirrorSource;
  bool matchesFamily(String? owner, String? source) =>
      childOwner != null &&
      mirrorSource != null &&
      childOwner == owner &&
      mirrorSource == source;
  final MealDecisionTimeoutFallback timeoutFallback;
  final MealAdvice? fallbackAdvice;
  DateTime get responseDeadline =>
      snapshot.capturedAt.add(const Duration(minutes: 5));

  /// Wire contract: only identity and request metadata leave the child's UI.
  Map<String, Object> toRequestPayload() {
    if (mealId == null) throw StateError('A real meal reference is required');
    return {
      'requestId': id,
      'mealId': mealId!,
      'requestedAt': snapshot.capturedAt.millisecondsSinceEpoch,
    };
  }

  final DateTime? claimExpiresAt;
  final bool claimExpired;
  final String? transferredFrom, transferredTo;
  final MealDecisionDemoStage stage;
  final bool caregiverPresent;
  final MealDecisionDemoSnapshot snapshot;
  final MealDecisionDemoStatus status;
  final MealDecisionDemoAnswer? answer;
  final int waitMinutes;
  final String? caregiverName;
  final String? claimedBy;
  final String? claimedById, caregiverId;
  final MealAdvice? acceptedAdvice;
  final String message;
  final bool suggestMealTarget;
  final DateTime? deferredUntil;

  MealDecisionDemoRequest withStatus(
    MealDecisionDemoStatus next, {
    MealDecisionTimeoutFallback? timeoutFallback,
    MealAdvice? fallbackAdvice,
    DateTime? claimExpiresAt,
    bool? claimExpired,
    bool clearClaim = false,
    String? transferredFrom,
    String? transferredTo,
    MealDecisionDemoStage? stage,
    bool? caregiverPresent,
    String? claimedBy,
    String? claimedById,
    MealAdvice? acceptedAdvice,
  }) => MealDecisionDemoRequest(
    id: id,
    mealId: mealId,
    childOwner: childOwner,
    mirrorSource: mirrorSource,
    timeoutFallback: timeoutFallback ?? this.timeoutFallback,
    fallbackAdvice: fallbackAdvice ?? this.fallbackAdvice,
    key: key,
    mealName: mealName,
    snapshot: snapshot,
    status: next,
    claimExpiresAt: clearClaim ? null : claimExpiresAt ?? this.claimExpiresAt,
    claimExpired: claimExpired ?? this.claimExpired,
    transferredFrom: transferredFrom ?? this.transferredFrom,
    transferredTo: transferredTo ?? this.transferredTo,
    stage: stage ?? this.stage,
    caregiverPresent: caregiverPresent ?? this.caregiverPresent,
    claimedBy: clearClaim ? null : claimedBy ?? this.claimedBy,
    claimedById: clearClaim ? null : claimedById ?? this.claimedById,
    caregiverId: caregiverId,
    acceptedAdvice: acceptedAdvice ?? this.acceptedAdvice,
    answer: answer,
    waitMinutes: waitMinutes,
    caregiverName: caregiverName,
    message: message,
    suggestMealTarget: suggestMealTarget,
    deferredUntil: deferredUntil,
  );
}
