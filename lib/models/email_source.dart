class EmailSource {
  final String id;
  final String userId;
  final String kind; // 'address' | 'domain'
  final String value;
  final String? label;
  final bool enabled;
  final DateTime? createdAt;

  const EmailSource({
    required this.id,
    required this.userId,
    required this.kind,
    required this.value,
    this.label,
    this.enabled = true,
    this.createdAt,
  });

  factory EmailSource.fromMap(Map<String, dynamic> m) {
    return EmailSource(
      id: m['id'] as String,
      userId: m['user_id'] as String? ?? '',
      kind: m['kind'] as String? ?? 'address',
      value: m['value'] as String? ?? '',
      label: m['label'] as String?,
      enabled: m['enabled'] as bool? ?? true,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'])?.toLocal() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'kind': kind,
      'value': value,
      if (label != null) 'label': label,
      'enabled': enabled,
    };
  }

  bool get isDomain => kind == 'domain';
  bool get isAddress => kind == 'address';
}

