import '../../setup/domain/setup_feature.dart';
import '../family_pairing_invitation.dart';
import '../family_pairing_repository.dart';

class CreateFamilyInvitationUseCase {
  const CreateFamilyInvitationUseCase(this.repository);
  final FamilyPairingRepository repository;
  Future<FamilyPairingInvitation> call(SetupDeviceMode mode) =>
      repository.createInvitation(mode);
}
