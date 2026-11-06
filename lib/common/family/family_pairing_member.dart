enum FamilyMemberRole { child, caregiver, managingCaregiver }

class FamilyPairingMember {
  const FamilyPairingMember({
    required this.id,
    required this.displayName,
    required this.role,
    required this.invitationId,
  });
  final String id;
  final String displayName;
  final FamilyMemberRole role;
  final String invitationId;
}
