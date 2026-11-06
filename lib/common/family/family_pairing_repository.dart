import '../setup/domain/setup_feature.dart';
import 'family_pairing_invitation.dart';
import 'family_pairing_member.dart';

/// The membership source can later be backed by an authorized Firebase stream.
abstract interface class FamilyPairingRepository {
  Future<FamilyPairingInvitation> createInvitation(SetupDeviceMode mode);
  Stream<List<FamilyPairingMember>> watchMembers(SetupDeviceMode mode);
}
