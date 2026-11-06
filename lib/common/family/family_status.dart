import 'family_join_request.dart';
import 'family_pairing_member.dart';

class FamilyStatus {
  const FamilyStatus({
    this.members = const [],
    this.pending,
    this.canLeave = false,
    this.joinState,
    this.invitationState,
    this.activeInvitationId,
    this.activeInvitationRevision = 0,
  });
  final List<FamilyPairingMember> members;
  final FamilyJoinRequest? pending;
  final bool canLeave;
  final String? joinState;
  final String? invitationState;
  final String? activeInvitationId;
  final int activeInvitationRevision;
}
