import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../repositories/meal_wizard_link_repository.dart';

final mealWizardLinkRepositoryProvider = Provider(
  (ref) => MealWizardLinkRepository(ref.watch(databaseProvider)),
);
