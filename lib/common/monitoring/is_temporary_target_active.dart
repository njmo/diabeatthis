import 'package:clock/clock.dart';

import '../../core/domain/model/temporary_target.dart';

bool isTemporaryTargetActive(TemporaryTarget? target) {
  if (target == null || !target.isValid || target.duration <= 0) return false;

  final now = clock.now();
  return !now.isBefore(target.createdAt) &&
      now.isBefore(target.createdAt.add(Duration(minutes: target.duration)));
}
