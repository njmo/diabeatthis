import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/temporary_target.dart';
import '../../../../core/logger/logger.dart';

part 'temporary_target_ui_provider.g.dart';

@Riverpod(keepAlive: true)
class TemporaryTargetUiNotifier extends _$TemporaryTargetUiNotifier with Logging{
  @override
  TemporaryTarget? build() => null;

  void update(TemporaryTarget target) {
    if (target.isActive()) {
      logI("Temporary target is active");
      state = target;
    } else {
      logI("Temporary target is not active");
      state = null;
    }
  }
}
