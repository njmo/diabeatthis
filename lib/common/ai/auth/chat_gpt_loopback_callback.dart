import 'dart:async';
import 'dart:io';

import 'chat_gpt_auth_exception.dart';
import 'chat_gpt_callback_page.dart';

class ChatGptLoopbackCallback {
  ChatGptLoopbackCallback._(this._server, this.state, this.page) {
    _subscription = _server.listen(_handle);
    // Cancellation may happen while the browser is still opening.
    unawaited(result.then<void>((_) {}, onError: (Object _) {}));
  }

  final HttpServer _server;
  final String state;
  final ChatGptCallbackPage? page;
  final Completer<Uri> _result = Completer<Uri>();
  late final StreamSubscription<HttpRequest> _subscription;
  bool _closed = false;

  static Future<ChatGptLoopbackCallback> start(
    String state, {
    ChatGptCallbackPage? page,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return ChatGptLoopbackCallback._(server, state, page);
  }

  Uri get redirectUri => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: _server.port,
    path: '/auth/callback',
  );

  Future<Uri> get result => _result.future;

  Future<void> _handle(HttpRequest request) async {
    if (request.method != 'GET' ||
        request.uri.path != redirectUri.path ||
        request.uri.queryParametersAll['state']?.length != 1 ||
        request.uri.queryParameters['state'] != state ||
        _result.isCompleted) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    request.response.headers.set('Cache-Control', 'no-store');
    request.response.headers.set('Referrer-Policy', 'no-referrer');
    final callbackPage = page;
    if (callbackPage == null) {
      request.response.statusCode = HttpStatus.noContent;
    } else {
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.html;
      request.response.headers.set(
        'Content-Security-Policy',
        ChatGptCallbackPage.contentSecurityPolicy,
      );
      request.response.headers.set('X-Content-Type-Options', 'nosniff');
      request.response.write(callbackPage.html);
    }
    final callback = request.uri;
    await request.response.close();
    if (!_result.isCompleted) _result.complete(callback);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_result.isCompleted) {
      _result.completeError(chatGptAuthorizationFailure());
    }
    await _subscription.cancel();
    await _server.close(force: true);
  }
}
