import 'dart:convert';

/// Localized browser content, independent of OAuth tokens and callback parameters.
class ChatGptCallbackPage {
  const ChatGptCallbackPage({required this.title, required this.message});

  final String title;
  final String message;

  static const contentSecurityPolicy =
      "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; "
      "form-action 'none'; frame-ancestors 'none'";

  String get html {
    const escape = HtmlEscape(HtmlEscapeMode.element);
    final safeTitle = escape.convert(title);
    final safeMessage = escape.convert(message);
    return '''<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$safeTitle</title>
<style>
body { margin: 0; padding: 32px 24px; font-family: system-ui, sans-serif;
  color: #1c2430; background: #f6f8fa; }
main { max-width: 480px; margin: 48px auto; }
h1 { font-size: 24px; line-height: 1.3; }
p { font-size: 17px; line-height: 1.6; }
</style>
</head>
<body><main><h1>$safeTitle</h1><p>$safeMessage</p></main></body>
</html>''';
  }
}
