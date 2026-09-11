import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../domain/use_cases/confirm_reviewed_meal_use_case.dart';
import 'meal_wizard_link_repository_provider.dart';

final confirmReviewedMealUseCaseProvider = Provider(
  (ref) => ConfirmReviewedMealUseCase(
    ref.watch(databaseProvider),
    ref.watch(mealWizardLinkRepositoryProvider),
  ),
);
