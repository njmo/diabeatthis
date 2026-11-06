import '../setup/domain/setup_feature.dart';
import 'family_management_context.dart';

/// Implementations must enforce membership authorization at the data boundary.
abstract interface class FamilyMembershipRepository {
  Future<void> disconnectMember(
    SetupDeviceMode mode,
    String memberId,
    FamilyManagementContext context,
  );
}
