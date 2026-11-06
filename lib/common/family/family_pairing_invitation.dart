class FamilyPairingInvitation {
  const FamilyPairingInvitation({
    required this.id,
    required this.code,
    this.revision = 0,
  });
  final String id;
  final String code;
  final int revision;
}
