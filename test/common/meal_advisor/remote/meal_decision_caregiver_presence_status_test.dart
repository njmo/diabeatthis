import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/meal_decision_caregiver_roster.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final present in [false, true]) {
    testWidgets('claimed caregiver presence icon: present=$present', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MealDecisionCaregiverStatus(
              request: MealDecisionRemoteRequest({
                'claimedByUid': 'parent',
                'presentUntil': present
                    ? DateTime.now()
                          .add(const Duration(minutes: 1))
                          .millisecondsSinceEpoch
                    : 0,
              }),
              member: const {'uid': 'parent', 'displayName': 'Alex'},
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(
        icon.icon,
        present ? Icons.check_circle_outline : Icons.warning_amber_rounded,
      );
      expect(
        icon.color,
        present ? Colors.green.shade400 : Colors.amber.shade600,
      );
    });
  }
}
