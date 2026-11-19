import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_preferences_provider.dart';
import 'package:diabeatthis/common/family_chat/domain/family_chat_preferences.dart';
import 'package:diabeatthis/common/family_chat/presentation/family_chat_configuration.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'setup receipt recovers exact pending OFF after restart without a second draft write',
    () async {
      SharedPreferences.setMockInitialValues({
        initialConfigurationDoneKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final pending = const FamilyChatPreferences()
          .copyWith(enabled: false)
          .asPendingSetup();
      await prefs.setString(
        familyChatPreferencesKey('child'),
        pending.encode(),
      );
      final binding = (uid: 'child', nonce: pending.changeId!);
      expect(hasConfigurationBinding(prefs, binding), false);
      await completeInitialConfiguration(prefs, binding: binding);
      // The persisted draft intentionally remains pending: no second write exists.
      expect(
        FamilyChatPreferences.decode(
          prefs.getString(familyChatPreferencesKey('child')),
        ).setupCommitted,
        false,
      );
      final container = ProviderContainer(
        overrides: [
          googleAccountProvider.overrideWith(
            (ref) => Stream.value(const GoogleAccount(uid: 'child')),
          ),
          sharedPrefsProvider.overrideWith((ref) async => prefs),
        ],
      );
      addTearDown(container.dispose);
      container.listen(googleAccountProvider, (_, _) {});
      await container.read(googleAccountProvider.future);
      await container.read(sharedPrefsProvider.future);
      final recovered = container.read(familyChatPreferencesProvider);
      expect(recovered.setupCommitted, true);
      expect(recovered.enabled, false);
      expect(recovered.accountExplicit, true);
      expect(
        hasConfigurationBinding(prefs, (uid: 'other', nonce: binding.nonce)),
        false,
      );
      expect(
        hasConfigurationBinding(prefs, (uid: 'child', nonce: 'older')),
        false,
      );
      await prefs.remove(initialConfigurationDoneKey);
      expect(hasInitialConfiguration(prefs), true);
    },
  );
  test(
    'configuration defaults, preserves OFF and fails closed on corruption',
    () {
      expect(FamilyChatPreferences.decode(null).enabled, isTrue);
      expect(FamilyChatPreferences.decode(null).retention, ChatRetention.week);
      const disabled = FamilyChatPreferences(
        enabled: false,
        retention: ChatRetention.month,
      );
      expect(FamilyChatPreferences.decode(disabled.encode()).enabled, isFalse);
      expect(
        FamilyChatPreferences.decode(disabled.encode()).retention,
        ChatRetention.month,
      );
      expect(FamilyChatPreferences.decode('{').enabled, isFalse);
    },
  );

  test('failed setup rolls back only its own account preference', () async {
    SharedPreferences.setMockInitialValues({
      familyChatPreferencesKey('other'): const FamilyChatPreferences(
        enabled: false,
      ).encode(),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        googleAccountProvider.overrideWith(
          (ref) => Stream.value(const GoogleAccount(uid: 'child')),
        ),
        sharedPrefsProvider.overrideWith((ref) async => prefs),
      ],
    );
    addTearDown(container.dispose);
    container.listen(googleAccountProvider, (_, _) {});
    await container.read(googleAccountProvider.future);
    await container.read(sharedPrefsProvider.future);
    expect(
      await container.read(configureFamilyChatPreferencesProvider)(
        const FamilyChatPreferences(enabled: false),
        (_) async => false,
        expectedUid: 'child',
      ),
      isFalse,
    );
    expect(prefs.containsKey(familyChatPreferencesKey('child')), isFalse);
    expect(
      FamilyChatPreferences.decode(
        prefs.getString(familyChatPreferencesKey('other')),
      ).enabled,
      isFalse,
    );
    await container.read(saveFamilyChatPreferencesProvider)(
      const FamilyChatPreferences(enabled: false),
      expectedUid: 'child',
    );
    expect(container.read(familyChatPreferencesProvider).enabled, isFalse);
    var applied = false;
    await expectLater(
      container.read(configureFamilyChatPreferencesProvider)(
        const FamilyChatPreferences(),
        (_) async {
          applied = true;
          return true;
        },
        expectedUid: 'other',
      ),
      throwsStateError,
    );
    expect(applied, isFalse);
    await expectLater(
      container.read(saveFamilyChatPreferencesProvider)(
        const FamilyChatPreferences(),
        expectedUid: 'other',
      ),
      throwsStateError,
    );
  });

  test('setup retains the production account preference namespace', () async {
    const productionKey = 'family_chat.preferences.child';
    const formerFixtureKey = 'family_chat_local_e2e.preferences.child';
    const production = FamilyChatPreferences(
      enabled: false,
      retention: ChatRetention.month,
    );
    const formerFixture = FamilyChatPreferences(retention: ChatRetention.day);
    SharedPreferences.setMockInitialValues({
      productionKey: production.encode(),
      formerFixtureKey: formerFixture.encode(),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        googleAccountProvider.overrideWith(
          (ref) => Stream.value(const GoogleAccount(uid: 'child')),
        ),
        sharedPrefsProvider.overrideWith((ref) async => prefs),
      ],
    );
    addTearDown(container.dispose);
    container.listen(googleAccountProvider, (_, _) {});
    await container.read(googleAccountProvider.future);
    await container.read(sharedPrefsProvider.future);
    final saved = container.read(familyChatPreferencesProvider);
    expect(saved.enabled, isFalse);
    expect(saved.retention, ChatRetention.month);
    await container.read(saveFamilyChatPreferencesProvider)(
      saved.copyWith(retention: ChatRetention.week),
      expectedUid: 'child',
    );
    expect(
      FamilyChatPreferences.decode(prefs.getString(productionKey)).retention,
      ChatRetention.week,
    );
    expect(prefs.getString(formerFixtureKey), formerFixture.encode());
  });

  for (final committed in [false, true]) {
    test(
      'setup interruption preserves only receipt-committed draft: $committed',
      () async {
        SharedPreferences.setMockInitialValues({
          initialConfigurationDoneKey: true,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'child')),
            ),
            sharedPrefsProvider.overrideWith((ref) async => prefs),
          ],
        );
        addTearDown(container.dispose);
        container.listen(googleAccountProvider, (_, _) {});
        await container.read(googleAccountProvider.future);
        await container.read(sharedPrefsProvider.future);
        final configure = container.read(
          configureFamilyChatPreferencesProvider,
        );
        Future<bool> attempt() => configure(
          const FamilyChatPreferences().copyWith(enabled: false),
          (binding) async {
            if (committed) {
              await completeInitialConfiguration(prefs, binding: binding);
            }
            throw StateError('Interrupted after main setup work');
          },
          expectedUid: 'child',
        );
        if (committed) {
          expect(await attempt(), true);
          expect(
            container.read(familyChatPreferencesProvider).setupCommitted,
            true,
          );
          expect(container.read(familyChatPreferencesProvider).enabled, false);
          // A subsequent non-chat setup cannot invalidate the accepted draft.
          await completeInitialConfiguration(prefs);
          container.invalidate(familyChatPreferencesProvider);
          expect(
            container.read(familyChatPreferencesProvider).setupCommitted,
            true,
          );
        } else {
          await expectLater(attempt(), throwsStateError);
          expect(prefs.getString(familyChatPreferencesKey('child')), isNull);
        }
      },
    );
  }

  testWidgets(
    'wizard loads saved OFF after login and rejects stale account loads',
    (tester) async {
      final a = Completer<FamilyChatPreferences?>();
      final b = Completer<FamilyChatPreferences?>();
      var fail = true;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: SetupWizardState(
              config: const DataSourceConfig(
                bgSource: BgSource.aaps,
                treatmentsSource: TreatmentsSource.aaps,
                pumpStatusSource: PumpStatusSource.aaps,
                historySource: HistorySource.local,
                mirrorToLocal: false,
              ),
              language: const ApplicationLanguage(
                code: 'en',
                locale: Locale('en'),
              ),
              name: '',
              nightscoutUrl: '',
              nightscoutToken: '',
            ),
            availability: const DataSourceOptionAvailability(
              aapsInstalled: true,
              xdripInstalled: true,
            ),
            loadFamilyChatPreferences: (uid) {
              if (uid == 'failure') {
                return fail
                    ? Future.error(StateError('read failed'))
                    : Future.value(const FamilyChatPreferences(enabled: false));
              }
              return uid == 'a' ? a.future : b.future;
            },
          ),
        ),
      );
      final controller = tester
          .state<SetupWizardViewState>(find.byType(SetupWizard))
          .controller;
      controller.applyGoogleAccount(const GoogleAccount(uid: 'a'));
      await tester.pump();
      expect(controller.state.familyChatPreferencesReady, isFalse);
      controller.applyGoogleAccount(const GoogleAccount(uid: 'b'));
      b.complete(const FamilyChatPreferences(enabled: false));
      await tester.pump();
      expect(controller.state.familyChatPreferences.enabled, isFalse);
      expect(controller.state.familyChatPreferencesReady, isTrue);
      a.complete(const FamilyChatPreferences());
      await tester.pump();
      expect(controller.state.familyChatPreferences.enabled, isFalse);
      controller.setFamilyChatPreferences(
        const FamilyChatPreferences(retention: ChatRetention.day),
      );
      controller.applyGoogleAccount(const GoogleAccount(uid: 'a'));
      await tester.pump();
      controller.applyGoogleAccount(const GoogleAccount(uid: 'b'));
      await tester.pump();
      expect(
        controller.state.familyChatPreferences.retention,
        ChatRetention.day,
      );
      controller.applyGoogleAccount(const GoogleAccount(uid: 'failure'));
      await tester.pump();
      expect(controller.state.familyChatLoadFailed, isTrue);
      expect(controller.state.familyChatPreferencesReady, isFalse);
      fail = false;
      controller.retryChatPreferences();
      await tester.pump();
      expect(controller.state.familyChatPreferencesReady, isTrue);
      expect(controller.state.familyChatPreferences.enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'init and settings share independent enable and retention controls',
    (tester) async {
      var value = const FamilyChatPreferences();
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => FamilyChatConfiguration(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      expect(find.text('7 dniach'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<ChatRetention>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('24 godzinach').last);
      await tester.pumpAndSettle();
      expect(value.retention, ChatRetention.day);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(value.enabled, isFalse);
      expect(find.byType(DropdownButtonFormField<ChatRetention>), findsNothing);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(value.retention, ChatRetention.day);
    },
  );
}
