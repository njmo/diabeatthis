class FamilyMirrorRecord {
  const FamilyMirrorRecord({
    required this.kind,
    required this.id,
    required this.revision,
    required this.deleted,
    this.payload,
  });
  final String kind;
  final String id;
  final int revision;
  final bool deleted;
  final Map<String, dynamic>? payload;
  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    'revision': revision,
    'deleted': deleted,
    'payload': payload,
  };
}
