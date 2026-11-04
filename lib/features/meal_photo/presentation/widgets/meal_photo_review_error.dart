import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/llm/llm_output_limit_exception.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../domain/models/meal_photo_review_exception.dart';

class MealPhotoReviewError extends StatelessWidget {
  const MealPhotoReviewError({super.key, required this.error});
  final Object error;
  @override
  Widget build(BuildContext context) => Text(switch (error) {
    LlmOutputLimitException() => context.lang.mealPhotoResponseIncomplete,
    FormatException() => context.lang.mealPhotoResponseInvalid,
    TimeoutException() => context.lang.mealPhotoRequestTimeout,
    LlmRequestException(failure: LlmRequestFailure.timeout) =>
      context.lang.mealPhotoRequestTimeout,
    LlmRequestException(failure: LlmRequestFailure.unauthorized) =>
      context.lang.mealPhotoRequestUnauthorized,
    LlmRequestException(failure: LlmRequestFailure.quotaExceeded) =>
      context.lang.mealPhotoRequestQuota,
    LlmRequestException() => context.lang.mealPhotoRequestConnection,
    LocalLlmUnavailableException() => context.lang.mealPhotoAiNotConfigured,
    MealPhotoReviewException(
      failure: MealPhotoReviewFailure.energyMacrosRequired,
    ) =>
      context.lang.ingredientEnergyMacrosRequired,
    MealPhotoReviewException(
      failure: MealPhotoReviewFailure.actionableCarbsRequired,
    ) =>
      context.lang.mealActionableCarbsRequired,
    MealPhotoReviewException(failure: MealPhotoReviewFailure.invalidMass) =>
      context.lang.mealPhotoInvalidReview,
    MealPhotoReviewException(
      failure: MealPhotoReviewFailure.invalidCarbohydrateFacts,
    ) =>
      context.lang.uiForNonEULabelsCarbohydratesMustBeGreaterThan,
    MealPhotoReviewException(
      failure: MealPhotoReviewFailure.legacyReferenceUnsupported,
    ) =>
      context.lang.mealPhotoLegacyReferenceUnsupported,
    MealPhotoReviewException(
      failure: MealPhotoReviewFailure.futureTimeRequired,
    ) =>
      context.lang.mealPhotoFutureTimeRequired,
    _ => context.lang.mealPhotoFailure,
  });
}
