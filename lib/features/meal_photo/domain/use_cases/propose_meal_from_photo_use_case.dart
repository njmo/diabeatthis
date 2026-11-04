import '../models/meal_photo_input.dart';
import '../models/meal_photo_model_response.dart';
import '../models/meal_photo_proposal.dart';
import '../models/meal_photo_proposal_stage.dart';
import '../ports/meal_photo_candidate_repository.dart';
import '../ports/meal_photo_recognition_client.dart';
import '../services/meal_photo_proposal_parser.dart';

class ProposeMealFromPhotoUseCase {
  const ProposeMealFromPhotoUseCase({
    required this.client,
    required this.candidates,
    this.parser = const MealPhotoProposalParser(),
  });
  final MealPhotoRecognitionClient client;
  final MealPhotoCandidateRepository candidates;
  final MealPhotoProposalParser parser;
  Future<MealPhotoProposal> call(
    MealPhotoInput input, {
    required String languageCode,
    void Function(MealPhotoProposalStage stage)? onProgress,
    void Function(MealPhotoModelResponse response)? onModelResponse,
  }) async {
    input.validate();
    final localizedInput = input.withLanguageCode(languageCode);
    onProgress?.call(MealPhotoProposalStage.recognizing);
    final description = await client.describe(localizedInput);
    onModelResponse?.call(
      MealPhotoModelResponse(
        stage: MealPhotoResponseStage.description,
        text: description,
      ),
    );
    onProgress?.call(MealPhotoProposalStage.validating);
    return parser.parse(description);
  }
}
