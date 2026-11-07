import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family/presentation/family_management_page.dart';
import 'package:diabeatthis/common/family/presentation/family_settings_section.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'family_settings_sheet_loading_test.dart' show LoadingFamilyRepository;

void main() {
  testWidgets(
    'family sheet fits small rosters, grows to its cap and shrinks after changes',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = LoadingFamilyRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            applicationDeviceModeProvider.overrideWith(
              (ref) async => ApplicationDeviceMode.caregiver,
            ),
            secureFamilyRepositoryProvider.overrideWithValue(repository),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(body: FamilySettingsSection()),
          ),
        ),
      );
      await tester.pump();
      final context = tester.element(find.byType(FamilySettingsSection));
      await tester.tap(find.text(context.lang.familyManageAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      repository.statuses.add(
        const FamilyStatus(
          members: [
            FamilyPairingMember(
              id: 'child',
              displayName: 'Child',
              role: FamilyMemberRole.child,
              invitationId: 'invite',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final short = tester.getSize(find.byType(FamilyManagementPage)).height;
      expect(short, lessThan(600));
      expect(short, greaterThan(200));
      repository.statuses.add(
        FamilyStatus(
          members: [
            for (var i = 0; i < 20; i++)
              FamilyPairingMember(
                id: '$i',
                displayName: 'Child $i',
                role: FamilyMemberRole.child,
                invitationId: '$i',
              ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final tall = tester.getSize(find.byType(FamilyManagementPage)).height;
      expect(tall, greaterThan(short));
      expect(tall, lessThanOrEqualTo(810));
      repository.statuses.add(
        const FamilyStatus(
          members: [
            FamilyPairingMember(
              id: 'child',
              displayName: 'Child',
              role: FamilyMemberRole.child,
              invitationId: 'invite',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FamilyManagementPage)).height, short);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.statuses.close);
    },
  );
}
