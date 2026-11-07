import 'dart:convert';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family_sync/enable_initial_family_sharing.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/caregiver/caregiver_configuration_test.dart'
    show CaregiverGoogleRepository;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    'unlinked',
    'linked',
    'offline',
    'changed-consent',
    'completed',
    'account-changed',
  ]) {
    test(
      'interrupted sharing reconciles deselection safely: $scenario',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = DatabaseImpl(NativeDatabase.memory());
        final auth = CaregiverGoogleRepository(
          const GoogleAccount(uid: 'child'),
        );
        final transport = AuthenticatedCallableTransport(
          projectId: 'test',
          currentUid: () => auth.account?.uid,
          identity: () async =>
              CallableIdentity(auth.account!.uid, 'token', 'check'),
          client: MockClient((request) async {
            if (scenario == 'offline') throw StateError('Offline');
            return http.Response(
              jsonEncode({
                'result': {
                  'members': scenario == 'linked'
                      ? [
                          {'id': 'parent'},
                        ]
                      : [],
                },
              }),
              200,
            );
          }),
        );
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            databaseProvider.overrideWithValue(db),
            googleAuthenticationRepositoryProvider.overrideWithValue(auth),
            authenticatedFamilyTransportProvider.overrideWithValue(transport),
          ],
        );
        await container.read(enableInitialFamilySharingProvider)();
        expect(prefs.getString(initialFamilySharingPendingKey), isNotNull);
        if (scenario == 'changed-consent') {
          await db.customStatement(
            'UPDATE family_sync_identity SET enabled_revision=enabled_revision+1',
          );
        }
        if (scenario == 'completed') {
          await prefs.setBool(initialConfigurationDoneKey, true);
        }
        if (scenario == 'account-changed') {
          auth.account = const GoogleAccount(uid: 'different');
        }
        final operation = container.read(reconcileInitialFamilySharingProvider)(
          false,
        );
        if (['linked', 'offline', 'account-changed'].contains(scenario)) {
          await expectLater(
            operation,
            throwsA(isA<FamilySharingSetupFailure>()),
          );
          expect(prefs.getString(initialFamilySharingPendingKey), isNotNull);
        } else {
          await operation;
          expect(prefs.getString(initialFamilySharingPendingKey), isNull);
        }
        expect(
          (await db
                  .customSelect('SELECT enabled FROM family_sync_identity')
                  .getSingle())
              .read<int>('enabled'),
          scenario == 'unlinked' ? 0 : 1,
        );
        container.dispose();
        transport.client.close();
        await db.close();
      },
    );
  }
}
