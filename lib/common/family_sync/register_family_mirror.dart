import '../backend/authenticated_callable_transport.dart';
import 'call_family_activity_protocol.dart';

Future<Map<String, dynamic>> registerFamilyMirror({
  required AuthenticatedCallableTransport transport,
  required String source,
  required String uid,
  required Future<bool> Function() permitted,
}) async {
  try {
    return await transport.call(
      'registerFamilyMirror',
      {
        'sourceId': source,
        'activityCommandsVersion': familyPlanningProtocolVersion,
        'mealHeadersExportVersion': 1,
      },
      expectedUid: uid,
      allowRequest: permitted,
    );
  } on CallableFailure catch (error) {
    // Older servers reject the extra field before writing the registration.
    if (error.rejectionCode != 'invalid-argument') rethrow;
  }
  return callFamilyActivityProtocol(
    transport: transport,
    name: 'registerFamilyMirror',
    activityCommandsVersion: familyPlanningProtocolVersion,
    data: {'sourceId': source},
    uid: uid,
    permitted: permitted,
  );
}
