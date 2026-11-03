import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/select_preceding_target_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 11, 3, 12);
  TemporaryTarget target(int offset, int duration) => TemporaryTarget(
    nightscoutId: '$offset',
    createdAt: at.add(Duration(minutes: offset)),
    durationInMiliseconds: duration * 60000,
    duration: duration,
    targetBottom: 90,
    targetTop: 90,
  );
  const select = SelectPrecedingTargetUseCase();
  test(
    'shows a target started before eating without using a future target',
    () {
      final entry = select([target(-20, 60), target(5, 60)], at)!;
      expect(entry.target.createdAt, at.subtract(const Duration(minutes: 20)));
      expect(entry.active, isTrue);
    },
  );
  test('cancellation ends the prior target instead of keeping it active', () {
    final entry = select([target(-20, 60), target(-5, 0)], at)!;
    expect(entry.active, isFalse);
    expect(entry.end, at.subtract(const Duration(minutes: 5)));
  });
  test('replacement wins and old expired targets are omitted', () {
    expect(
      select([target(-40, 60), target(-10, 30)], at)!.target.createdAt,
      at.subtract(const Duration(minutes: 10)),
    );
    expect(select([target(-240, 20)], at), isNull);
    expect(select(null, at), isNull);
  });
}
