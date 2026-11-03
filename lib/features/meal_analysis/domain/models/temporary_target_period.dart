import '../../../../core/domain/model/temporary_target.dart';

class TemporaryTargetPeriod {
  const TemporaryTargetPeriod({required this.target, required this.end});
  final TemporaryTarget target;
  final DateTime end;
}
