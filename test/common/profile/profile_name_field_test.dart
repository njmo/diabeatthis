import 'package:diabeatthis/common/widgets/profile_name_field.dart';
import 'package:diabeatthis/common/widgets/profile_photo_picker.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'editing the name updates avatar initials and saves the form value',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final form = GlobalKey<FormState>();
      String? savedName;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => preferences),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: Form(
                key: form,
                child: ProfileNameField(
                  label: 'Imię',
                  initialValue: 'Maria',
                  onSaved: (value) => savedName = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePhotoPicker), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Maria Kowalska');
      await tester.pump();
      expect(find.text('MK'), findsOneWidget);
      form.currentState!.save();
      expect(savedName, 'Maria Kowalska');
    },
  );
}
