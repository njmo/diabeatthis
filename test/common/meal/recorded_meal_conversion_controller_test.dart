import 'package:diabeatthis/common/meal/recorded_meal_conversion_controller.dart';
import 'package:diabeatthis/common/meal/recorded_meal_conversion_repository.dart';
import 'package:diabeatthis/common/meal/recorded_meal_conversion_request.dart';
import 'package:diabeatthis/common/meal/review_recorded_meal_conversion_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeConversionReviewUseCase
    implements ReviewRecordedMealConversionUseCase {
  int writes = 0;
  bool failLoad = false;
  @override
  RecordedMealConversionRepository get repository => throw UnimplementedError();
  @override
  Future<List<RecordedMealConversionRequest>> load(int mealId) async {
    if (failLoad) throw StateError('unavailable');
    return [];
  }

  @override
  Future<void> confirm(
    Map<RecordedMealConversionRequest, double> reviewed,
  ) async {
    writes++;
  }
}

void main() {
  test(
    'review cancellation never writes and confirmation delegates once',
    () async {
      final useCase = FakeConversionReviewUseCase();
      final container = ProviderContainer(
        overrides: [
          reviewRecordedMealConversionUseCaseProvider.overrideWithValue(
            useCase,
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = recordedMealConversionControllerProvider(1);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      expect(await controller.begin(), isEmpty);
      expect(container.read(provider).isLoading, isTrue);
      controller.cancel();
      expect(container.read(provider).isLoading, isFalse);
      expect(useCase.writes, 0);
      await controller.begin();
      expect(await controller.confirm({}), isTrue);
      expect(useCase.writes, 1);
    },
  );
  test(
    'load failures are exposed as controller state and can be retried',
    () async {
      final useCase = FakeConversionReviewUseCase()..failLoad = true;
      final container = ProviderContainer(
        overrides: [
          reviewRecordedMealConversionUseCaseProvider.overrideWithValue(
            useCase,
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = recordedMealConversionControllerProvider(1);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final controller = container.read(provider.notifier);
      expect(await controller.begin(), isNull);
      expect(container.read(provider).hasError, isTrue);
      useCase.failLoad = false;
      expect(await controller.begin(), isEmpty);
      controller.cancel();
      expect(container.read(provider).hasError, isFalse);
    },
  );
}
