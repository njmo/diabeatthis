import 'package:flutter/foundation.dart';

import 'authenticated_callable_transport.dart';

/// TEMPORARY testing diagnostics for family sync failures. `debugPrint`
/// reaches logcat in release builds. Never log tokens or payloads.
void familySyncDiag(String message) => debugPrint('[FamilySyncDiag] $message');

String familySyncDiagError(Object error) => error is CallableFailure
    ? 'CallableFailure(code=${error.code}, rejection=${error.rejectionCode}, '
          'reason=${error.rejectionReason})'
    : '${error.runtimeType}: $error';
