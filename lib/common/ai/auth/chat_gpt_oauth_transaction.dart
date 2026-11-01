import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class ChatGptOAuthTransaction {
  ChatGptOAuthTransaction({Random? random}) {
    final source = random ?? Random.secure();
    state = randomValue(source);
    nonce = randomValue(source);
    verifier = randomValue(source);
  }

  late final String state;
  late final String nonce;
  late final String verifier;

  String get challenge => base64Url
      .encode(sha256.convert(ascii.encode(verifier)).bytes)
      .replaceAll('=', '');

  static String randomValue(Random random) => base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');

  static String newHostId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'urn:uuid:${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
