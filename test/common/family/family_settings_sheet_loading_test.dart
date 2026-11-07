import 'dart:async';

import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family/presentation/family_loading_state.dart';
import 'package:diabeatthis/common/family/presentation/family_management_page.dart';
import 'package:diabeatthis/common/family/presentation/family_settings_section.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_sync_settings_section.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/settings_action_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'secure_family_panel_test.dart' show PendingSecureFamilyRepository;

class LoadingFamilyRepository extends PendingSecureFamilyRepository {
  final statuses = StreamController<FamilyStatus>.broadcast();
  @override
  Stream<FamilyStatus> watchStatus() => statuses.stream;
}

void main() {
  testWidgets(
    'Family card exposes management and sync; management sheet loads the roster',
    (tester) async {
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
      expect(find.byType(FamilySyncSettingsSection), findsOneWidget);
      expect(find.byType(SettingsActionRow), findsNWidgets(2));
      final settingsContext = tester.element(
        find.byType(FamilySettingsSection),
      );
      await tester.tap(find.text(settingsContext.lang.familyManageAction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FamilyManagementPage), findsOneWidget);
      final pageContext = tester.element(find.byType(FamilyManagementPage));
      expect(ModalRoute.of(pageContext), isA<ModalBottomSheetRoute<void>>());
      expect(find.byType(FamilyLoadingState), findsOneWidget);
      repository.statuses.add(
        const FamilyStatus(
          members: [
            FamilyPairingMember(
              id: 'child',
              displayName: 'Child account',
              role: FamilyMemberRole.child,
              invitationId: 'invite',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FamilyLoadingState), findsNothing);
      expect(find.text('Child account'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FamilyManagementPage),
          matching: find.byType(FamilySyncSettingsSection),
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.statuses.close);
    },
  );
}
