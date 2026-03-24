import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/observers/riverpod_debug_observer.dart';

final ProviderContainer appContainer = ProviderContainer(
  observers: [
    if (kDebugMode) RiverpodDebugObserver(env: 'ui')
  ],
);
