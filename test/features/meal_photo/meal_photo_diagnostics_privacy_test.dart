import 'package:diabeatthis/core/logger/logger.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

class PrivateFormatFailureClient extends TestPhotoClient {
  @override
  Future<String> describe(MealPhotoInput input) async =>
      throw const FormatException('PRIVATE_MESSAGE', 'PRIVATE_PAYLOAD');
}

void main() {
  test(
    'generation logs stage and failure category without model or user content',
    () async {
      final previous = LogRuntimeConfig.bufferEnabled;
      LogRuntimeConfig.bufferEnabled = true;
      Log.clearBuffer();
      addTearDown(() {
        Log.clearBuffer();
        LogRuntimeConfig.bufferEnabled = previous;
      });
      final candidates = TestPhotoCandidates();
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: PrivateFormatFailureClient(),
          candidates: candidates,
        ),
        saver: TestPhotoSaver(),
      );
      addTearDown(controller.dispose);
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'PRIVATE_IMAGE_PATH.jpg',
          description: 'PRIVATE_USER_DESCRIPTION',
        ),
        languageCode: 'en',
      );
      expect(controller.state.error, isA<FormatException>());
      expect(candidates.queries, isEmpty);
      final logs = Log.bufferedLogs
          .where((entry) => entry.tag == 'MealPhotoController')
          .toList();
      expect(
        logs.any((entry) => entry.message.contains('stage=recognizing')),
        isTrue,
      );
      expect(
        logs.any(
          (entry) => entry.message.contains('reason=response.invalid_format'),
        ),
        isTrue,
      );
      for (final entry in logs) {
        expect(entry.toLine(), isNot(contains('PRIVATE')));
        expect(entry.error, isNull);
      }
    },
  );
}
