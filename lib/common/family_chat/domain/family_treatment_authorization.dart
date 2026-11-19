typedef FamilyTreatmentAuthorization = ({
  String epoch,
  int accountOffGeneration,
  int familyOffGeneration,
});

FamilyTreatmentAuthorization? parseFamilyTreatmentAuthorization(Object? value) {
  if (value is! Map || value.length != 3) return null;
  final epoch = value['epoch'];
  final account = value['accountOffGeneration'];
  final family = value['familyOffGeneration'];
  bool generation(Object? v) => v is int && v >= 0 && v <= 9007199254740991;
  if (epoch is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(epoch) ||
      !generation(account) ||
      !generation(family)) {
    return null;
  }
  return (
    epoch: epoch,
    accountOffGeneration: account as int,
    familyOffGeneration: family as int,
  );
}

Map<String, Object> familyTreatmentAuthorizationJson(
  FamilyTreatmentAuthorization value,
) => {
  'epoch': value.epoch,
  'accountOffGeneration': value.accountOffGeneration,
  'familyOffGeneration': value.familyOffGeneration,
};

FamilyTreatmentAuthorization? familyTreatmentAuthorizationFromConfig(
  Map config,
) => parseFamilyTreatmentAuthorization({
  'epoch': config['epoch'],
  'accountOffGeneration': config['account']?['offGeneration'],
  'familyOffGeneration': config['policy']?['offGeneration'],
});
