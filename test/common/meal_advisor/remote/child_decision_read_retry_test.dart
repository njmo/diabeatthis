import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/child_meal_decision_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_controller.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _ChildInbox extends MealDecisionRemoteController {
  _ChildInbox(this.request, this.transport);
  final Map<String, Object?> request;
  final AuthenticatedCallableTransport transport;

  @override
  MealDecisionRemoteInbox build() => MealDecisionRemoteInbox(
    accountUid: 'child',
    requests: [MealDecisionRemoteRequest(request)],
  );

  @override
  Future<Map<String, dynamic>> execute(
    String action,
    Map<String, Object?> values, {
    bool refresh = true,
  }) => transport.call('mealDecision', {
    'action': action,
    ...values,
  }, expectedUid: 'child');
}

void main() {
  testWidgets('child retries a 502 read and shows the same request answer', (
    tester,
  ) async {
    final id = 'a' * 32;
    final now = DateTime.now();
    final waiting = <String, Object?>{
      'id': id,
      'mealId': '1',
      'status': 'waiting',
      'createdAt': now.millisecondsSinceEpoch,
      'deadline': now.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
    };
    final actions = <Object?>[];
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map;
      actions.add((body['data'] as Map)['action']);
      if (actions.length == 1) return http.Response('Bad gateway', 502);
      return http.Response(
        jsonEncode({
          'result': {
            'requests': [
              {
                ...waiting,
                'status': 'answered',
                'response': {
                  'caregiverName': 'Caregiver',
                  'decision': {'type': 'eatThenInsulin'},
                },
              },
            ],
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealDecisionPreferencesProvider.overrideWithValue(
            const MealDecisionPreferences(method: MealDecisionMethod.caregiver),
          ),
          mealDecisionRemoteControllerProvider.overrideWith(
            () => _ChildInbox(
              waiting,
              AuthenticatedCallableTransport(
                client: client,
                projectId: 'test',
                currentUid: () => 'child',
                identity: () async =>
                    const CallableIdentity('child', 'id-token', 'app-check'),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ChildMealDecisionSheet(
                    mealId: 1,
                    mealName: 'Lunch',
                    initialRequestId: id,
                  ),
                ),
                child: const Text('Open decision'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open decision'));
    await tester.pumpAndSettle();
    expect(actions, ['fetch']);
    expect(find.text('Accept'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.close),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(actions, ['fetch', 'fetch']);
    expect(find.text('Accept'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ChildMealDecisionSheet), findsNothing);
    expect(find.text('Open decision'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
