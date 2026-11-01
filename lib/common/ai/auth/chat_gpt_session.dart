import 'chat_gpt_auth_exception.dart';

class ChatGptSession {
  const ChatGptSession({
    required this.clientId,
    required this.subject,
    this.accessToken,
    this.refreshToken,
    this.idToken,
    this.expiresAt,
    this.earliestRefreshAt,
    this.scopes = const [],
  });

  final String clientId;
  final String subject;
  final String? accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? expiresAt;
  final DateTime? earliestRefreshAt;
  final List<String> scopes;

  bool get isConnected =>
      accessToken?.isNotEmpty == true &&
      refreshToken?.isNotEmpty == true &&
      scopes.contains('resource.invoke') &&
      scopes.contains('chatgpt.tokens.use.direct');

  ChatGptSession signedOut() =>
      ChatGptSession(clientId: clientId, subject: subject);

  factory ChatGptSession.fromTokenResponse({
    required String clientId,
    required String subject,
    required Map<String, dynamic> response,
    required DateTime now,
    ChatGptSession? previous,
  }) {
    final access = response['access_token'];
    final refresh = response['refresh_token'];
    final id = response['id_token'] ?? previous?.idToken;
    final expires = response['expires_in'];
    final scope = response['scope'];
    final scopes = scope is String
        ? scope
              .split(RegExp(r'\s+'))
              .where((value) => value.isNotEmpty)
              .toList()
        : previous?.scopes ?? <String>[];
    if (clientId == 'dynamic_agent_client' ||
        clientId.isEmpty ||
        subject.isEmpty ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        id is! String ||
        id.isEmpty ||
        expires is! num ||
        !expires.isFinite ||
        expires <= 0 ||
        response['token_type'] is! String ||
        (response['token_type'] as String).toLowerCase() != 'bearer' ||
        !scopes.contains('resource.invoke') ||
        !scopes.contains('chatgpt.tokens.use.direct')) {
      throw chatGptAuthorizationFailure();
    }
    final earliest = response['earliest_refresh_at'];
    return ChatGptSession(
      clientId: clientId,
      subject: subject,
      accessToken: access,
      refreshToken: refresh,
      idToken: id,
      expiresAt: now.toUtc().add(Duration(seconds: expires.toInt())),
      earliestRefreshAt: earliest is num && earliest.isFinite
          ? DateTime.fromMillisecondsSinceEpoch(
              earliest.toInt() * 1000,
              isUtc: true,
            )
          : earliest is String
          ? DateTime.tryParse(earliest)?.toUtc()
          : null,
      scopes: scopes,
    );
  }

  factory ChatGptSession.fromJson(Map<String, dynamic> json) {
    final clientId = json['client_id'] as String;
    final subject = json['subject'] as String;
    if (clientId.isEmpty ||
        clientId == 'dynamic_agent_client' ||
        subject.isEmpty) {
      throw chatGptAuthorizationFailure();
    }
    return ChatGptSession(
      clientId: clientId,
      subject: subject,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      earliestRefreshAt: DateTime.tryParse(
        json['earliest_refresh_at'] as String? ?? '',
      ),
      scopes: List<String>.from(json['scopes'] as List? ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'client_id': clientId,
    'subject': subject,
    if (accessToken != null) 'access_token': accessToken,
    if (refreshToken != null) 'refresh_token': refreshToken,
    if (idToken != null) 'id_token': idToken,
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    if (earliestRefreshAt != null)
      'earliest_refresh_at': earliestRefreshAt!.toUtc().toIso8601String(),
    'scopes': scopes,
  };
}
