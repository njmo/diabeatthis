import '../../setup/domain/setup_feature.dart';
import '../family_management_context.dart';
import '../family_membership_repository.dart';
import '../family_pairing_repository.dart';

class DisconnectFamilyMemberUseCase {
  const DisconnectFamilyMemberUseCase(this.repository);
  final FamilyPairingRepository repository;

  bool canDisconnect(SetupDeviceMode mode, FamilyManagementContext context) =>
      repository is FamilyMembershipRepository &&
      (mode == SetupDeviceMode.caregiver ||
          context == FamilyManagementContext.initialSetup);

  Future<void> call(
    SetupDeviceMode mode,
    String memberId,
    FamilyManagementContext context,
  ) async {
    if (!canDisconnect(mode, context)) {
      throw StateError('Family disconnection is not permitted');
    }
    await (repository as FamilyMembershipRepository).disconnectMember(
      mode,
      memberId,
      context,
    );
  }
}
