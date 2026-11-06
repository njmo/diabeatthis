class FamilyJoinRequest {
  const FamilyJoinRequest({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.email = '',
  });
  final String id;
  final String displayName;
  final String? photoUrl;
  final String email;
}
