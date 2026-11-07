import 'dart:async';

import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_sync_page.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

class GuardedSyncTestPage extends FamilySyncPage {
  const GuardedSyncTestPage({super.key});
  @override
  FamilySyncPageState createState() => GuardedSyncTestPageState();
}

class GuardedSyncTestPageState extends FamilySyncPageState {
  @override
  void start() {}
  @override
  void initState() {
    listeningUid = 'child';
    loadedUid = 'child';
    enabled = true;
    super.initState();
  }
}

void main() {
  testWidgets(
    'sync cannot be disabled on loading paired or failed family status; stale actions recheck',
    (tester) async {
      final statuses = StreamController<FamilyStatus>.broadcast();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'child')),
            ),
            applicationDeviceModeProvider.overrideWith(
              (ref) async => ApplicationDeviceMode.patient,
            ),
            secureFamilyStatusProvider.overrideWith(
              (ref, uid) => statuses.stream,
            ),
            databaseProvider.overrideWith(
              (ref) => throw StateError('A blocked toggle must not write'),
            ),
          ],
          child: localizedMaterialApp(home: const GuardedSyncTestPage()),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      statuses.add(const FamilyStatus());
      await tester.pumpAndSettle();
      final oldToggle = tester
          .widget<SwitchListTile>(find.byType(SwitchListTile))
          .onChanged!;
      statuses.add(
        const FamilyStatus(
          members: [
            FamilyPairingMember(
              id: 'parent',
              displayName: 'Parent',
              role: FamilyMemberRole.caregiver,
              invitationId: 'invite',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      oldToggle(false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      statuses.addError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(statuses.close);
    },
  );
}
