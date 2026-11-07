import '../backend/authenticated_callable_transport.dart';
import '../l10n/language.dart';

String familyPlanningFailureMessage(AppLocalizations language, Object error) {
  if (error is! CallableFailure) return language.familyPlanFailed;
  return switch (error.rejectionCode ?? error.code) {
    'unauthenticated' => language.familyGoogleRequired,
    'permission-denied' => language.familyOperationFailed,
    'failed-precondition' => language.familyPlanNotReady,
    _ => language.familyPlanFailed,
  };
}
