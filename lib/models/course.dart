class Course {
  final String id;
  final String userId;
  final String name;
  final String? code;
  final String? professor;
  final DateTime? createdAt;

  Course({
    required this.id,
    required this.userId,
    required this.name,
    this.code,
    this.professor,
    this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['course_name'] as String? ?? '',
      code: json['course_code'] as String?,
      professor: json['professor'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'course_name': name,
      if (code != null) 'course_code': code,
      if (professor != null) 'professor': professor,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }

  Course copyWith({
    String? id,
    String? userId,
    String? name,
    String? code,
    String? professor,
    DateTime? createdAt,
  }) {
    return Course(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      code: code ?? this.code,
      professor: professor ?? this.professor,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}