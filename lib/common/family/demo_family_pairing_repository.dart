import 'dart:async';

import '../setup/domain/setup_feature.dart';
import 'family_pairing_invitation.dart';
import 'family_pairing_member.dart';
import 'family_pairing_repository.dart';

/// In-memory demo data only. Codes are intentionally unusable for real pairing.
class DemoFamilyPairingRepository implements FamilyPairingRepository {
  final channels = {
    for (final mode in SetupDeviceMode.values)
      mode: StreamController<List<FamilyPairingMember>>.broadcast(sync: true),
  };
  final members = <SetupDeviceMode, List<FamilyPairingMember>>{};
  final invitations = <SetupDeviceMode, FamilyPairingInvitation>{};
  int sequence = 0;

  @override
  Future<FamilyPairingInvitation> createInvitation(SetupDeviceMode mode) async {
    final invitation = FamilyPairingInvitation(
      id: 'demo-${++sequence}',
      code: 'DEMO-${sequence.toString().padLeft(4, '0')}',
    );
    invitations[mode] = invitation;
    return invitation;
  }

  @override
  Stream<List<FamilyPairingMember>> watchMembers(SetupDeviceMode mode) {
    scheduleMicrotask(() {
      final channel = channels[mode]!;
      if (!channel.isClosed) {
        channel.add(List.unmodifiable(members[mode] ?? []));
      }
    });
    return channels[mode]!.stream;
  }

  void simulatePairing(SetupDeviceMode mode) {
    final invitation = invitations[mode];
    if (invitation == null) return;
    final current = members.putIfAbsent(mode, () => []);
    if (current.any((member) => member.invitationId == invitation.id)) return;
    current.add(
      FamilyPairingMember(
        id: 'member-${invitation.id}',
        displayName: mode == SetupDeviceMode.patient
            ? (current.isEmpty ? 'Alex Morgan' : 'Taylor Morgan')
            : 'Sam Morgan',
        role: mode == SetupDeviceMode.patient
            ? (current.isEmpty
                  ? FamilyMemberRole.managingCaregiver
                  : FamilyMemberRole.caregiver)
            : FamilyMemberRole.child,
        invitationId: invitation.id,
      ),
    );
    channels[mode]!.add(List.unmodifiable(current));
  }

  void dispose() {
    for (final channel in channels.values) {
      unawaited(channel.close());
    }
  }
}
