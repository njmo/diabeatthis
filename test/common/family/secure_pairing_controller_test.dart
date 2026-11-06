import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_repository.dart';
import 'package:diabeatthis/common/family/family_pairing_invitation.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family/secure_family_repository.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingSecureFamilyRepository implements SecureFamilyRepository {
  int invitations = 0;
  @override
  Future<FamilyPairingInvitation> createInvitation(SetupDeviceMode mode) async {
    invitations++;
    return const FamilyPairingInvitation(id: 'invite', code: 'secret');
  }

  @override
  Stream<List<FamilyPairingMember>> watchMembers(SetupDeviceMode mode) =>
      const Stream.empty();
  @override
  Stream<FamilyStatus> watchStatus() => const Stream.empty();
  @override
  Future<void> requestJoin(String code) async {}
  @override
  Future<void> decide(String id, {required bool approve}) async {}
  @override
  Future<void> disconnect(String id) async {}
  @override
  Future<void> finalizeSetup() async {}
}

class PairingGoogleAuthentication implements GoogleAuthenticationRepository {
  @override
  bool get isSupported => true;
  @override
  Stream<GoogleAccount?> watchAccount() => const Stream.empty();
  @override
  Future<GoogleAccount?> signIn() async =>
      const GoogleAccount(uid: 'future-parent');
  @override
  Future<void> signOut() async {}
}

void main() {
  test(
    'Google login before role selection never creates a child family in live pairing',
    () async {
      final repository = RecordingSecureFamilyRepository();
      final state = SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode('en'),
        name: '',
        nightscoutUrl: '',
        nightscoutToken: '',
      );
      final controller = SetupWizardController(
        state,
        familyRepository: repository,
        authentication: PairingGoogleAuthentication(),
      );
      addTearDown(controller.dispose);
      controller.applyGoogleAccount(
        const GoogleAccount(uid: 'future-parent', displayName: 'Parent'),
      );
      controller.setMode(SetupDeviceMode.caregiver);
      await Future<void>.delayed(Duration.zero);
      expect(state.signedIn, isTrue);
      expect(state.mode, SetupDeviceMode.caregiver);
      expect(repository.invitations, 0);
      expect(state.pairingInvitation, isNull);
    },
  );
}
