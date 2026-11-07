import 'dart:async';

import 'package:diabeatthis/common/family/family_join_request.dart';
import 'package:diabeatthis/common/family/family_pairing_invitation.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family/presentation/family_pairing_qr_card.dart';
import 'package:diabeatthis/common/family/presentation/secure_family_panel.dart';
import 'package:diabeatthis/common/family/secure_family_repository.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/localized_material_app.dart';

class FamilyPanelVisualRepository implements SecureFamilyRepository {
  FamilyPanelVisualRepository(this.updates);
  final Stream<FamilyStatus> updates;
  String? disconnectedId;
  @override
  Future<void> disconnect(String memberId) async {
    disconnectedId = memberId;
  }

  @override
  Stream<FamilyStatus> watchStatus() => updates;
  @override
  Future<FamilyPairingInvitation> createInvitation(
    SetupDeviceMode mode,
  ) async => const FamilyPairingInvitation(id: 'invite', code: 'private-qr');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'generated QR is compact, high contrast and revealed after expansion',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final updates = StreamController<FamilyStatus>.broadcast();
      final scroll = ScrollController();
      final repository = FamilyPanelVisualRepository(updates.stream);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 900),
                  SecureFamilyPanel(
                    repository: repository,
                    mode: SetupDeviceMode.patient,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      updates.add(const FamilyStatus());
      await tester.pump();
      await tester.ensureVisible(find.text('Dodaj opiekuna'));
      await tester.tap(find.text('Dodaj opiekuna'));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(
        tester.getSize(find.byType(QrImageView)).width,
        lessThanOrEqualTo(180),
      );
      final paper = qr.backgroundColor.computeLuminance();
      final ink = qr.eyeStyle.color!.computeLuminance();
      expect((paper + .05) / (ink + .05), greaterThan(7));
      final card = tester.getRect(find.byType(FamilyPairingQrCard));
      expect(card.top, greaterThanOrEqualTo(0));
      expect(card.bottom, lessThanOrEqualTo(700));
      updates.add(
        const FamilyStatus(
          pending: FamilyJoinRequest(
            id: 'pending',
            displayName: 'Parent',
            email: 'parent@example.test',
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(
        tester.getRect(find.text('parent@example.test')).top,
        greaterThanOrEqualTo(0),
      );
      expect(
        tester.getRect(find.text('Zatwierdź')).bottom,
        lessThanOrEqualTo(700),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await updates.close();
      scroll.dispose();
    },
  );
  testWidgets(
    'caregiver disconnect action on child row unlinks the caller, without duplicate leave button',
    (tester) async {
      final repository = FamilyPanelVisualRepository(
        Stream.value(
          const FamilyStatus(
            canLeave: true,
            members: [
              FamilyPairingMember(
                id: 'child-uid',
                displayName: 'Child',
                role: FamilyMemberRole.child,
                invitationId: 'invite',
                canDisconnect: true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SecureFamilyPanel(
              repository: repository,
              mode: SetupDeviceMode.caregiver,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Opuść rodzinę'), findsNothing);
      await tester.tap(find.byIcon(Icons.link_off));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Odłącz'));
      await tester.pumpAndSettle();
      expect(repository.disconnectedId, 'self');
    },
  );
}
