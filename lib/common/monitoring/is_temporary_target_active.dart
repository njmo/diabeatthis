import 'package:clock/clock.dart';

import '../../core/domain/model/temporary_target.dart';

bool isTemporaryTargetActive(TemporaryTarget? target, {DateTime? at}) {
  if (target == null || !target.isValid || target.duration <= 0) return false;

  final now = at ?? clock.now();
  return !now.isBefore(target.createdAt) &&
      now.isBefore(target.createdAt.add(Duration(minutes: target.duration)));
}
