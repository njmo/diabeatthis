import '../../setup/domain/setup_feature.dart';
import '../demo_family_pairing_repository.dart';
import '../family_pairing_repository.dart';

/// Explicitly limited to the in-memory pairing preview.
class SimulateFamilyPairingUseCase {
  const SimulateFamilyPairingUseCase(this.repository);
  final FamilyPairingRepository repository;
  void call(SetupDeviceMode mode) {
    final source = repository;
    if (source is DemoFamilyPairingRepository) source.simulatePairing(mode);
  }
}
