import 'quick_low_treatment_slot.dart';

class QuickLowTreatmentItemsState {
  const QuickLowTreatmentItemsState({
    required this.slots,
    this.isSaving = false,
  });

  final List<QuickLowTreatmentSlot> slots;
  final bool isSaving;

  QuickLowTreatmentItemsState copyWith({
    List<QuickLowTreatmentSlot>? slots,
    bool? isSaving,
  }) {
    return QuickLowTreatmentItemsState(
      slots: slots ?? this.slots,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
