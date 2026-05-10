import '../../data/models/ingredient_details_data.dart';

class IngredientPageState {
  final IngredientDetailsData data;
  final bool isEditing;
  final bool isSaving;

  const IngredientPageState({
    required this.data,
    this.isEditing = false,
    this.isSaving = false,
  });

  IngredientPageState copyWith({
    IngredientDetailsData? data,
    bool? isEditing,
    bool? isSaving,
  }) {
    return IngredientPageState(
      data: data ?? this.data,
      isEditing: isEditing ?? this.isEditing,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}
