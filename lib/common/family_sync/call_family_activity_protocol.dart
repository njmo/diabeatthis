import '../backend/authenticated_callable_transport.dart';

/// Explicit protocol negotiation keeps new commands out of legacy child runners.
/// A legacy server still supports the original mirror/planning operations.
Future<Map<String, dynamic>> callFamilyActivityProtocol({
  required AuthenticatedCallableTransport transport,
  required String name,
  required Map<String, dynamic> data,
  required String uid,
  required Future<bool> Function() permitted,
  int activityCommandsVersion = 1,
}) async {
  for (final version in [
    for (var version = activityCommandsVersion; version > 0; version--) version,
    0,
  ]) {
    try {
      return await transport.call(
        name,
        {...data, if (version > 0) 'activityCommandsVersion': version},
        expectedUid: uid,
        allowRequest: permitted,
      );
    } on CallableFailure catch (error) {
      if (error.rejectionCode != 'invalid-argument' || version == 0) rethrow;
    }
  }
  throw StateError('Protocol negotiation exhausted');
}
