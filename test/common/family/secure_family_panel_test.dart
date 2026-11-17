import 'package:diabeatthis/common/family/family_join_request.dart';
import 'package:diabeatthis/common/family/family_pairing_invitation.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family/presentation/secure_family_panel.dart';
import 'package:diabeatthis/common/family/secure_family_repository.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

class PendingSecureFamilyRepository implements SecureFamilyRepository {
  int decisions = 0;
  int invitations = 0;
  @override
  Stream<FamilyStatus> watchStatus() => Stream.value(
    const FamilyStatus(
      pending: FamilyJoinRequest(
        id: 'invite',
        displayName: 'Parent',
        email: 'parent@example.test',
      ),
    ),
  );
  @override
  Stream<List<FamilyPairingMember>> watchMembers(SetupDeviceMode mode) =>
      const Stream.empty();
  @override
  Future<FamilyPairingInvitation> createInvitation(SetupDeviceMode mode) async {
    invitations++;
    return const FamilyPairingInvitation(id: 'invite', code: 'secret');
  }

  @override
  Future<void> decide(String id, {required bool approve}) async {
    decisions++;
  }

  @override
  Future<void> requestJoin(String code) async {}
  @override
  Future<void> requestJoinByCode(String code) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> disconnect(String id) async {}
  @override
  Future<void> finalizeSetup() async {}
}

void main() {
  testWidgets(
    'verified Google identity is visible and one explicit approval submits the decision',
    (tester) async {
      final repository = PendingSecureFamilyRepository();
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SecureFamilyPanel(
                repository: repository,
                mode: SetupDeviceMode.patient,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('parent@example.test'), findsOneWidget);
      expect(repository.invitations, 0);
      await tester.tap(find.text('Zatwierdź'));
      await tester.pumpAndSettle();
      expect(repository.decisions, 1);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
