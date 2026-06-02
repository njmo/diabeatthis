import '../../../../core/domain/model/ingredient.dart';
import '../drafts/ingredient_draft.dart';

class IngredientFilterItem {
  final int id;
  final String name;
  final bool removable;

  const IngredientFilterItem({
    required this.id,
    required this.name,
    required this.removable,
  });

  IngredientFilterItem copyWith({bool? removable}) {
    return IngredientFilterItem(
      id: id,
      name: name,
      removable: removable ?? this.removable,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is IngredientFilterItem &&
            other.id == id &&
            other.name == name &&
            other.removable == removable;
  }

  @override
  int get hashCode => Object.hash(id, name, removable);
}

extension IngredientFilterItemMapper on Ingredient {
  IngredientFilterItem toFilterItem({required bool removable}) {
    return IngredientFilterItem(id: id, name: name, removable: removable);
  }
}

extension IngredientDraftFilterItemMapper on IngredientDraft {
  IngredientFilterItem? toFilterItem({bool removable = false}) {
    return maybeMap(
      existing: (ingredient) => IngredientFilterItem(
        id: ingredient.id,
        name: ingredient.name,
        removable: removable,
      ),
      orElse: () => null,
    );
  }
}
