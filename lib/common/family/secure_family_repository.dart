import '../setup/domain/setup_feature.dart';
import 'family_pairing_invitation.dart';
import 'family_pairing_repository.dart';
import 'family_status.dart';

abstract interface class SecureFamilyRepository
    implements FamilyPairingRepository {
  @override
  Future<FamilyPairingInvitation> createInvitation(SetupDeviceMode mode);
  Stream<FamilyStatus> watchStatus();
  Future<void> requestJoin(String qrCode);
  Future<void> decide(String invitationId, {required bool approve});
  Future<void> disconnect(String memberId);
  Future<void> finalizeSetup();
}
