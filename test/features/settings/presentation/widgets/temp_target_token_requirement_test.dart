import 'package:diabeatthis/features/settings/presentation/widgets/nightscout_connection_fields.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/temp_target_settings_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'an enabled target option cannot validate an empty or whitespace token',
    (tester) async {
      final key = GlobalKey<FormState>();
      final url = TextEditingController(text: 'https://example.com');
      final token = TextEditingController(text: 'write-token');
      addTearDown(url.dispose);
      addTearDown(token.dispose);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Form(
              key: key,
              child: NightscoutConnectionFields(
                urlController: url,
                tokenController: token,
                tokenRequired: true,
              ),
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isTrue);
      token.text = '  ';
      await tester.pump();
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        find.textContaining('Przed włączeniem opcji uzupełnij token'),
        findsOneWidget,
      );
      token.text = '';
      expect(key.currentState!.validate(), isFalse);
    },
  );

  testWidgets('without a token the switch cannot enable uploads', (
    tester,
  ) async {
    var changed = false;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: TempTargetSettingsSwitch(
            value: false,
            hasToken: false,
            onChanged: (_) => changed = true,
          ),
        ),
      ),
    );
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    await tester.tap(find.byType(SwitchListTile));
    expect(changed, isFalse);
  });

  testWidgets(
    'removing a token still allows the user to disable an existing opt-in',
    (tester) async {
      bool? next;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: TempTargetSettingsSwitch(
              value: true,
              hasToken: false,
              onChanged: (value) => next = value,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(SwitchListTile));
      expect(next, isFalse);
    },
  );

  testWidgets(
    'connection fields and target switch cannot change during verification',
    (tester) async {
      var changed = false;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const NightscoutConnectionFields(
                  initialUrl: 'https://example.com',
                  initialToken: 'token',
                  enabled: false,
                ),
                TempTargetSettingsSwitch(
                  value: true,
                  hasToken: true,
                  enabled: false,
                  onChanged: (_) => changed = true,
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((field) => field.enabled == false),
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      await tester.tap(find.byType(SwitchListTile));
      expect(changed, isFalse);
    },
  );
}
