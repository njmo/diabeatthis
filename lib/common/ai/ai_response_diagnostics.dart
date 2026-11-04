import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Splits diagnostic payloads into numbered lines that fit Android logcat.
/// JSON encoding preserves newlines so the original payload can be recovered.
void printAiResponseDiagnostic({
  required String tag,
  required String requestId,
  required String stage,
  required String response,
  bool enabled = kDebugMode,
}) {
  if (!kDebugMode || !enabled) return;
  final payload = jsonEncode(response);
  const chunkSize = 800;
  final parts = (payload.length / chunkSize).ceil();
  for (var index = 0; index < parts; index++) {
    final start = index * chunkSize;
    final end = (start + chunkSize).clamp(0, payload.length);
    debugPrint(
      '[$tag] request=$requestId stage=$stage '
      'part=${index + 1}/$parts json=${payload.substring(start, end)}',
      wrapWidth: null,
    );
  }
}
