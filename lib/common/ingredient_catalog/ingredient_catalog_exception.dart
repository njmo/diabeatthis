enum IngredientCatalogFailure {
  unavailable,
  unauthorized,
  invalidResponse,
  staleCursor,
}

class IngredientCatalogException implements Exception {
  const IngredientCatalogException(this.failure, [this.message = '']);
  final IngredientCatalogFailure failure;
  final String message;
  @override
  String toString() => 'IngredientCatalogException(${failure.name})';
}
