import 'dart:convert';

import 'package:crypto/crypto.dart';

String nightscoutConnectionFingerprint(String url, String token) => sha256
    .convert(utf8.encode(jsonEncode([url.trim(), token.trim()])))
    .toString();
