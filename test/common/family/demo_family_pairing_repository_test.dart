import 'package:diabeatthis/common/family/demo_family_pairing_repository.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a fresh code preserves linked caregivers and repeated completion is idempotent',
    () async {
      final repository = DemoFamilyPairingRepository();
      addTearDown(repository.dispose);
      var members = <FamilyPairingMember>[];
      final subscription = repository
          .watchMembers(SetupDeviceMode.patient)
          .listen((value) => members = value);
      addTearDown(subscription.cancel);
      final first = await repository.createInvitation(SetupDeviceMode.patient);
      repository.simulatePairing(SetupDeviceMode.patient);
      repository.simulatePairing(SetupDeviceMode.patient);
      expect(members, hasLength(1));
      expect(members.single.role, FamilyMemberRole.managingCaregiver);
      final second = await repository.createInvitation(SetupDeviceMode.patient);
      expect(second.id, isNot(first.id));
      expect(second.code, isNot(first.code));
      expect(members, hasLength(1));
      repository.simulatePairing(SetupDeviceMode.patient);
      expect(members, hasLength(2));
      expect(members.last.role, FamilyMemberRole.caregiver);
      expect(members.first.id, isNot(members.last.id));
    },
  );

  test(
    'caregiver invitation emits a child record without leaking another mode',
    () async {
      final repository = DemoFamilyPairingRepository();
      addTearDown(repository.dispose);
      var members = <FamilyPairingMember>[];
      final subscription = repository
          .watchMembers(SetupDeviceMode.caregiver)
          .listen((value) => members = value);
      addTearDown(subscription.cancel);
      await repository.createInvitation(SetupDeviceMode.patient);
      repository.simulatePairing(SetupDeviceMode.patient);
      expect(members, isEmpty);
      await repository.createInvitation(SetupDeviceMode.caregiver);
      repository.simulatePairing(SetupDeviceMode.caregiver);
      expect(members.single.role, FamilyMemberRole.child);
    },
  );
}
