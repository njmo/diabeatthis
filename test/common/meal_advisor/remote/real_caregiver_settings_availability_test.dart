import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/meal_decision_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'the real managing caregiver role enables caregiver advice in child settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'child')),
            ),
            secureFamilyStatusProvider('child').overrideWith(
              (ref) => Stream.value(
                const FamilyStatus(
                  members: [
                    FamilyPairingMember(
                      id: 'parent',
                      displayName: 'Parent',
                      role: FamilyMemberRole.managingCaregiver,
                      invitationId: '',
                    ),
                  ],
                ),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: MealDecisionSettings()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final caregiver = tester
          .widgetList<RadioListTile<MealDecisionMethod>>(
            find.byType(RadioListTile<MealDecisionMethod>),
          )
          .singleWhere((tile) => tile.value == MealDecisionMethod.caregiver);
      expect(caregiver.enabled, isTrue);
    },
  );
}
