import '../../backend/authenticated_callable_transport.dart';

abstract interface class FamilyChatApi {
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  });
}

/// Dispatches chat callable operations through authenticated transport.
///
/// Unavoidable in-flight HTTP boundary:
/// Gating via [allowRequest] evaluates immediately before `http.Client.post`,
/// after asynchronous identity and App Check attestation have finished. If
/// local OFF or fence revocation occurs while identity was being resolved,
/// [allowRequest] rejects the call and zero HTTP requests are sent on the wire.
/// However, once `http.Client.post` has physically started transmitting bytes
/// across the socket, in-flight network bytes cannot be revoked remotely. Any
/// response returning from such an in-flight request is fenced upon arrival by
/// the session's generation/invalidation checks, preventing local side effects.
class FamilyChatRemote implements FamilyChatApi {
  const FamilyChatRemote(this.transport, this.uid);

  final AuthenticatedCallableTransport transport;
  final String uid;

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) => transport.call(
    operation,
    data,
    expectedUid: uid,
    allowRequest: allowRequest,
  );
}
