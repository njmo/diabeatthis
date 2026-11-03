import '../../../common/handoff/controllers/handoff_controller.dart';
import '../../../common/handoff/handoff_progress.dart';
import '../domain/models/low_treatment_pip_session.dart';

class ConfirmLowTreatmentAapsUseCase {
  const ConfirmLowTreatmentAapsUseCase(this.handoff);
  final HandoffController handoff;

  Future<void> call(int mealId) => handoff.publish(
    sessionId: LowTreatmentPipSession.forMeal(mealId),
    progress: HandoffProgress({LowTreatmentPipSession.carbsAction: true}),
    rowActionIds: [LowTreatmentPipSession.carbsAction],
  );
}
