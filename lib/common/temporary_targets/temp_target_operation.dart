import 'owned_temp_target.dart';
import 'temp_target_proposal.dart';

enum TempTargetOperationKind { start, stop }

enum TempTargetOperationStatus {
  pendingDelivery,
  awaitingConsent,
  declined,
  sending,
  sent,
  rejected,
  unknownResult,
  completed,
  superseded,
}

/// A durable consent and delivery record, independent of the notification UI.
class TempTargetOperation {
  const TempTargetOperation({
    required this.requestId,
    required this.kind,
    required this.entityId,
    required this.targetType,
    required this.source,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deliveredAt,
    this.proposal,
    this.attemptedTarget,
    this.confirmedTarget,
    this.stoppedAt,
    this.closedAt,
  });

  final String requestId;
  final TempTargetOperationKind kind;
  final int entityId;
  final String targetType;
  final String source;
  final TempTargetOperationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;
  final TempTargetProposal? proposal;
  final OwnedTempTarget? attemptedTarget;
  final OwnedTempTarget? confirmedTarget;
  final DateTime? stoppedAt;
  final DateTime? closedAt;

  OwnedTempTarget? get ownedTarget => confirmedTarget ?? attemptedTarget;

  Map<String, dynamic> payloadToJson() => {
    if (proposal != null) 'proposal': proposal!.toJson(),
    if (attemptedTarget != null) 'attemptedTarget': attemptedTarget!.toJson(),
    if (confirmedTarget != null) 'confirmedTarget': confirmedTarget!.toJson(),
    if (stoppedAt != null) 'stoppedAt': stoppedAt!.toUtc().toIso8601String(),
  };
}
