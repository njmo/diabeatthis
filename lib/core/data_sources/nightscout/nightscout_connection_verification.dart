import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nightscoutConnectionVerificationProvider = Provider(
  (ref) => NightscoutConnectionVerification(),
);

/// Reuses a recent setup check for the exact URL/token without retaining them.
class NightscoutConnectionVerification {
  NightscoutConnectionVerification({DateTime Function()? now})
    : now = now ?? DateTime.now;
  final DateTime Function() now;
  String? _fingerprint;
  DateTime? _verifiedAt;
  static const validity = Duration(minutes: 5);

  String _key(String url, String token) => sha256
      .convert(utf8.encode('${url.trim()}\u0000${token.trim()}'))
      .toString();

  void clear() {
    _fingerprint = null;
    _verifiedAt = null;
  }

  void remember({required String url, required String token}) {
    _fingerprint = _key(url, token);
    _verifiedAt = now();
  }

  bool matches({required String url, required String token}) {
    if (_verifiedAt == null || _fingerprint != _key(url, token)) return false;
    final age = now().difference(_verifiedAt!);
    return !age.isNegative && age <= validity;
  }
}
