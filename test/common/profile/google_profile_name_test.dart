import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/widgets/profile_name_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/localized_material_app.dart';
import '../../helpers/regression/setup_live_services.dart';

void main() {
  testWidgets(
    'Google name is displayed without overwriting the local profile draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final name = TextEditingController(text: 'Local child');
      addTearDown(name.dispose);
      final form = GlobalKey<FormState>();
      String? saved;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAuthenticationRepositoryProvider.overrideWithValue(auth),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: Form(
                key: form,
                child: ProfileNameField(
                  label: 'Name',
                  controller: name,
                  onSaved: (value) => saved = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      auth.accounts.add(
        const GoogleAccount(uid: 'a', displayName: 'Google Person'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Google Person'), findsOneWidget);
      expect(name.text, 'Local child');
      form.currentState!.save();
      expect(saved, 'Local child');
      auth.accounts.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Local child'), findsOneWidget);
      form.currentState!.save();
      expect(saved, 'Local child');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
