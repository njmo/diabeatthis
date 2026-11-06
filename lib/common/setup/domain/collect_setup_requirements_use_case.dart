import 'setup_feature.dart';

class CollectSetupRequirementsUseCase {
  const CollectSetupRequirementsUseCase();

  Map<SetupRequirement, Set<SetupFeatureId>> call(
    Iterable<SetupFeature> features,
  ) {
    final requirements = <SetupRequirement, Set<SetupFeatureId>>{};
    for (final feature in features) {
      for (final requirement in feature.requirements) {
        requirements.putIfAbsent(requirement, () => {}).add(feature.id);
      }
    }
    return Map.unmodifiable(
      requirements.map(
        (key, value) => MapEntry(key, Set<SetupFeatureId>.unmodifiable(value)),
      ),
    );
  }
}
