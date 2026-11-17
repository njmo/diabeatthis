class FamilyPairingInvitation {
  const FamilyPairingInvitation({
    required this.id,
    required this.code,
    this.revision = 0,
    this.shortCode,
    this.expiresAt,
  });
  final String id;
  final String code;
  final String? shortCode;
  final DateTime? expiresAt;
  final int revision;
}
