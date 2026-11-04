enum IngredientSource { local, firebase }

class IngredientIdentity {
  const IngredientIdentity({required this.source, required this.sourceId});
  final IngredientSource source;
  final String sourceId;
  String get stableKey => '${source.name}:$sourceId';
  bool get isValid =>
      sourceId.trim().isNotEmpty &&
      (source != IngredientSource.local || (int.tryParse(sourceId) ?? 0) > 0);
  Map<String, Object> toJson() => {'source': source.name, 'sourceId': sourceId};
  factory IngredientIdentity.fromJson(Map<String, dynamic> value) {
    final source = switch (value['source']) {
      'local' => IngredientSource.local,
      'firebase' => IngredientSource.firebase,
      _ => throw const FormatException('Unsupported ingredient source'),
    };
    final id = value['sourceId'];
    if (id is! String) {
      throw const FormatException('Missing ingredient identity');
    }
    final identity = IngredientIdentity(source: source, sourceId: id);
    if (!identity.isValid) {
      throw const FormatException('Invalid ingredient identity');
    }
    return identity;
  }
  @override
  bool operator ==(Object other) =>
      other is IngredientIdentity &&
      source == other.source &&
      sourceId == other.sourceId;
  @override
  int get hashCode => Object.hash(source, sourceId);
}
