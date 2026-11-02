import '../../../common/treatments/calculator_submission.dart';
import '../model/foreground_event.dart';

class CalculatorSubmissionChangedEvent extends ForegroundEvent {
  const CalculatorSubmissionChangedEvent(this.submission);

  final CalculatorSubmission submission;
}
