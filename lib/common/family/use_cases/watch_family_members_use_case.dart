import '../../setup/domain/setup_feature.dart';
import '../family_pairing_member.dart';
import '../family_pairing_repository.dart';

class WatchFamilyMembersUseCase {
  const WatchFamilyMembersUseCase(this.repository);
  final FamilyPairingRepository repository;
  Stream<List<FamilyPairingMember>> call(SetupDeviceMode mode) =>
      repository.watchMembers(mode);
}
