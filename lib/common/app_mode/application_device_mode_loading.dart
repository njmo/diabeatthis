import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/language.dart';
import 'application_device_mode.dart';

class ApplicationDeviceModeLoading extends ConsumerWidget {
  const ApplicationDeviceModeLoading({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(applicationDeviceModeProvider);
    return Scaffold(
      body: Center(
        child: mode.hasError
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.lang.deviceModeLoadFailed,
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(applicationDeviceModeProvider),
                    child: Text(context.lang.commonRetry),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
