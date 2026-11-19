import '../backend/authenticated_callable_transport.dart';
import 'call_family_activity_protocol.dart';

Future<void> registerFamilyMirror({
  required AuthenticatedCallableTransport transport,
  required String source,
  required String uid,
  required Future<bool> Function() permitted,
}) async {
  await callFamilyActivityProtocol(
    transport: transport,
    name: 'registerFamilyMirror',
    activityCommandsVersion: familyPlanningProtocolVersion,
    data: {'sourceId': source},
    uid: uid,
    permitted: permitted,
  );
}
