import '../../../common/l10n/language.dart';
import '../../meals/data/domain/use_cases/save_meal_draft_use_case.dart';
import '../../meals/data/drafts/meal_draft.dart';
import 'meal_photo_draft_writer.dart';

class SaveMealDraftPhotoWriter implements MealPhotoDraftWriter {
  const SaveMealDraftPhotoWriter({
    required this.saveMealDraft,
    required this.language,
  });
  final SaveMealDraftUseCase saveMealDraft;
  final AppLocalizations Function() language;
  @override
  Future<int> write(MealDraft draft) async => (await saveMealDraft(
    draft,
    automaticName: false,
    suggestMissingIcons: false,
    language: language(),
  )).id;
}
