import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../../features/meal_advisor/domain/models/wait_suggestion.dart';
import '../demo/meal_decision_demo_answer.dart';

/// Server-owned workflow metadata. Clinical context stays on the caregiver device.
class MealDecisionRemoteRequest {
  const MealDecisionRemoteRequest(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  int get mealId => int.parse('${data['mealId']}');
  String get ownerUid => data['ownerUid'] as String;
  String get sourceId => data['sourceId'] as String;
  String get mealName => data['mealName'] as String? ?? '';
  String get status => data['status'] as String;
  DateTime get deadline =>
      DateTime.fromMillisecondsSinceEpoch(data['deadline'] as int);
  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int);
  String? get claimedByUid => data['claimedByUid'] as String?;
  String? get claimedByName => data['claimedByName'] as String?;
  String get stage => data['stage'] as String? ?? 'context';
  bool get expired =>
      status == 'expired' ||
      (status != 'accepted' &&
          status != 'accepting' &&
          !DateTime.now().isBefore(deadline));
  bool get pending =>
      !expired && const {'waiting', 'answered', 'accepting'}.contains(status);
  bool timedOutAt(DateTime time) =>
      const {'waiting', 'answered', 'expired'}.contains(status) &&
      !time.isBefore(deadline) &&
      data['terminalReason'] != 'allCaregiversDeclined' &&
      (data['acceptanceAborted'] != true ||
          (data['completedAt'] is num &&
              (data['completedAt'] as num) >= deadline.millisecondsSinceEpoch));
  bool get claimAvailable =>
      data['claimAvailable'] == true ||
      claimedByUid == null ||
      (data['claimUntil'] is int &&
          (data['claimUntil'] as int) <= DateTime.now().millisecondsSinceEpoch);
  bool get present =>
      (data['presentUntil'] as num? ?? 0) >
      DateTime.now().millisecondsSinceEpoch;
  List<Map<String, dynamic>> get members => [
    for (final member in data['members'] as List? ?? [])
      Map<String, dynamic>.from(member as Map),
  ];
  Map<String, dynamic>? get response => data['response'] == null
      ? null
      : Map<String, dynamic>.from(data['response'] as Map);
  Map<String, dynamic>? get decision {
    final value = response;
    if (value == null) return null;
    return Map<String, dynamic>.from(
      value['decision'] is Map ? value['decision'] as Map : value,
    );
  }

  MealDecisionDemoAnswer? get answer => MealDecisionDemoAnswer.values
      .where((a) => a.name == decision?['type'])
      .firstOrNull;
  int get minutes => (decision?['minutes'] as num?)?.toInt() ?? 0;
  String? get respondingCaregiverUid => response?['caregiverUid'] as String?;
  String? get respondingCaregiverName => response?['caregiverName'] as String?;
  String get message => decision?['message'] as String? ?? '';
  MealAdvice? get advice => answer?.decision == null
      ? null
      : MealAdvice(
          answer!.decision,
          answer == MealDecisionDemoAnswer.insulinThenWait
              ? WaitSuggestion(minutes, minutes, minutes)
              : null,
          source: 'caregiver',
          caregiverId: respondingCaregiverUid,
          caregiverRequestId: id,
        );
}
