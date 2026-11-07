import 'dart:convert';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/common/planning/family_planning_failure_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'definitive server authentication refusal prompts Google sign-in',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'status': 'UNAUTHENTICATED'},
          }),
          401,
        ),
      );
      addTearDown(client.close);
      final transport = AuthenticatedCallableTransport(
        client: client,
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async =>
            const CallableIdentity('parent', 'token', 'appcheck'),
      );
      try {
        await transport.call('submitFamilyPlan', {});
        fail('Expected authentication rejection');
      } on CallableFailure catch (error) {
        expect(error.rejectionCode, 'unauthenticated');
        final language = AppLocalizationsPl();
        expect(
          familyPlanningFailureMessage(language, error),
          language.familyGoogleRequired,
        );
      }
    },
  );
}
