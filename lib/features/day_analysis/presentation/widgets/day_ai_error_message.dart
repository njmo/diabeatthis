import '../../../../common/analysis/ai_request_error_message.dart';
import '../../../../common/l10n/language.dart';
import '../../domain/models/day_analysis_invalid_response.dart';

String dayAiErrorMessage(AppLocalizations lang, Object? error) {
  if (error is DayAnalysisInvalidResponse && error.tokenLimitReached) {
    return lang.dayAiOutputLimit;
  }
  if (error is FormatException) return lang.dayAiInvalidResponse;
  return aiRequestErrorMessage(lang, error);
}
