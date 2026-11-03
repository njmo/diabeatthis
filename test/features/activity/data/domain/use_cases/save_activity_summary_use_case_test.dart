import 'package:diabeatthis/features/activity/data/domain/use_cases/save_activity_summary_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'normalizes optional notes while preserving the perceived intensity',
    () async {
      final saved = <(int, String?, String?)>[];
      final save = SaveActivitySummaryUseCase(
        saveCompleted:
            ({required id, required intensity, required notes}) async {
              saved.add((id, intensity, notes));
              return true;
            },
      );
      await save(id: 7, intensity: 'high', notes: '  A tough workout  ');
      await save(id: 7, intensity: null, notes: '   ');
      expect(saved, [(7, 'high', 'A tough workout'), (7, null, null)]);
    },
  );

  test(
    'reports removed or reopened activities instead of treating them as saved',
    () async {
      final save = SaveActivitySummaryUseCase(
        saveCompleted:
            ({required id, required intensity, required notes}) async => false,
      );
      await expectLater(
        save(id: 7, intensity: 'light', notes: 'Note'),
        throwsStateError,
      );
    },
  );
}
