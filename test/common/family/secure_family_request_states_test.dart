import 'dart:async';

import 'package:diabeatthis/common/family/family_pairing_invitation.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family/presentation/secure_family_panel.dart';
import 'package:diabeatthis/common/family/secure_family_repository.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../helpers/localized_material_app.dart';

class RequestStateFamilyRepository implements SecureFamilyRepository {
  RequestStateFamilyRepository(this.updates);
  final Stream<FamilyStatus> updates;
  @override
  Stream<FamilyStatus> watchStatus() => updates;
  @override
  Future<FamilyPairingInvitation> createInvitation(
    SetupDeviceMode mode,
  ) async =>
      const FamilyPairingInvitation(id: 'invitation', code: 'private-qr');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final state in ['rejected', 'expired', 'cancelled', 'revoked']) {
    testWidgets('$state request does not remain waiting for approval', (
      tester,
    ) async {
      final repository = RequestStateFamilyRepository(
        Stream.value(FamilyStatus(joinState: state)),
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
      expect(
        find.text(
          'Ta prośba jest już nieaktywna. Poproś o nowy kod i zeskanuj go ponownie.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Prośba wysłana.'), findsNothing);
    });
  }
  testWidgets(
    'confirmed QR holds a checkmark then collapses and reveals the account',
    (tester) async {
      final updates = StreamController<FamilyStatus>.broadcast();
      final repository = RequestStateFamilyRepository(updates.stream);
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
      updates.add(const FamilyStatus());
      await tester.pump();
      await tester.tap(find.text('Dodaj opiekuna'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      updates.add(
        const FamilyStatus(
          members: [
            FamilyPairingMember(
              id: 'parent',
              displayName: 'Parent Google',
              role: FamilyMemberRole.managingCaregiver,
              invitationId: 'invitation',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.text('Parent Google'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Parent Google'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await updates.close();
    },
  );

  testWidgets(
    'newer QR on a second device invalidates this QR; old status cannot invalidate a fresh one',
    (tester) async {
      final updates = StreamController<FamilyStatus>.broadcast();
      final repository = RequestStateFamilyRepository(updates.stream);
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
      updates.add(const FamilyStatus());
      await tester.pump();
      await tester.tap(find.text('Dodaj opiekuna'));
      await tester.pumpAndSettle();
      updates.add(
        const FamilyStatus(
          activeInvitationId: 'older-device-code',
          activeInvitationRevision: 0,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      updates.add(
        const FamilyStatus(
          activeInvitationId: 'newer-device-code',
          activeInvitationRevision: 1,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.textContaining('Ta prośba jest już nieaktywna.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await updates.close();
    },
  );
  testWidgets(
    'reduced motion confirms pairing without a zero-duration AnimatedSize',
    (tester) async {
      final updates = StreamController<FamilyStatus>.broadcast();
      final repository = RequestStateFamilyRepository(updates.stream);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SecureFamilyPanel(
                  repository: repository,
                  mode: SetupDeviceMode.patient,
                ),
              ),
            ),
          ),
        ),
      );
      updates.add(const FamilyStatus());
      await tester.pump();
      await tester.tap(find.text('Dodaj opiekuna'));
      await tester.pumpAndSettle();
      updates.add(
        const FamilyStatus(
          members: [
            FamilyPairingMember(
              id: 'parent',
              displayName: 'Parent Google',
              role: FamilyMemberRole.managingCaregiver,
              invitationId: 'invitation',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Parent Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await updates.close();
    },
  );
}
