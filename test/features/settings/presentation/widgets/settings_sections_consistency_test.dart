import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/auth/widgets/google_account_settings_row.dart';
import 'package:diabeatthis/common/auth/widgets/google_brand_mark.dart';
import 'package:diabeatthis/common/family/presentation/family_settings_section.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/location/residence_country_provider.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/application_theme_settings_section.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/google_account_settings_section.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/residence_country_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/regression/setup_live_services.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'settings cards share padding and Google logout works at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(380, 1700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final auth = SetupGoogleAuthenticationTestRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPrefsProvider.overrideWith((ref) async => prefs),
              googleAuthenticationRepositoryProvider.overrideWithValue(auth),
              deviceCountryLocalesProvider.overrideWithValue([
                const Locale('pl', 'PL'),
              ]),
            ],
            child: MaterialApp(
              locale: const Locale('pl'),
              theme: applicationThemeData(
                brightness: Brightness.dark,
                textTheme: ThemeData.dark().textTheme,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      GoogleAccountSettingsSection(),
                      SizedBox(height: 16),
                      FamilySettingsSection(),
                      SizedBox(height: 16),
                      ResidenceCountrySetting(),
                      SizedBox(height: 16),
                      ApplicationThemeSettingsSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        auth.accounts.add(
          const GoogleAccount(
            uid: 'parent',
            displayName: 'Parent Name',
            email: 'parent@example.test',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GoogleAccountSettingsRow), findsOneWidget);
        expect(find.byType(GoogleBrandMark), findsOneWidget);
        final cards =
            [
                  GoogleAccountSettingsSection,
                  FamilySettingsSection,
                  ResidenceCountrySetting,
                  ApplicationThemeSettingsSection,
                ]
                .map(
                  (type) => tester.getRect(
                    find
                        .descendant(
                          of: find.byType(type),
                          matching: find.byType(Card),
                        )
                        .first,
                  ),
                )
                .toList();
        for (var index = 0; index < cards.length; index++) {
          expect(cards[index].left, 16);
          expect(cards[index].width, 348);
          if (index > 0) expect(cards[index].top - cards[index - 1].bottom, 16);
        }
        final context = tester.element(
          find.byType(GoogleAccountSettingsSection),
        );
        await tester.tap(find.byTooltip(context.lang.setupGoogleSignOut));
        await tester.pumpAndSettle();
        expect(find.byType(GoogleAccountSettingsRow), findsNothing);
        expect(find.text(context.lang.setupGoogleSignIn), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(auth.dispose);
      },
    );
  }
}
