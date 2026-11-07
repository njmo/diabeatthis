import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/common/planning/family_planning_failure_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'server refusals use localized explanations rather than exception instance names',
    () {
      final language = AppLocalizationsPl();
      expect(
        familyPlanningFailureMessage(
          language,
          const CallableFailure(
            'unavailable',
            rejectionCode: 'failed-precondition',
          ),
        ),
        language.familyPlanNotReady,
      );
      expect(
        familyPlanningFailureMessage(
          language,
          const CallableFailure('unauthenticated'),
        ),
        language.familyGoogleRequired,
      );
      expect(
        familyPlanningFailureMessage(
          language,
          const CallableFailure(
            'unavailable',
            rejectionCode: 'permission-denied',
          ),
        ),
        language.familyOperationFailed,
      );
      expect(
        familyPlanningFailureMessage(
          language,
          const CallableFailure('unavailable'),
        ),
        language.familyPlanFailed,
      );
    },
  );
}
