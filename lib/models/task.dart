import 'course.dart';

class Task {
  final String id;
  final String userId;
  final String? courseId;
  final String title;
  final String? description;
  final String? type;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? createdAt;
  final Course? course;

  Task({
    required this.id,
    required this.userId,
    this.courseId,
    required this.title,
    this.description,
    this.type = 'assignment',
    this.dueDate,
    this.isCompleted = false,
    this.createdAt,
    this.course,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    Course? courseObj;
    if (json['courses'] != null && json['courses'] is Map<String, dynamic>) {
      courseObj = Course.fromJson(json['courses'] as Map<String, dynamic>);
    } else if (json['course'] != null && json['course'] is Map<String, dynamic>) {
      courseObj = Course.fromJson(json['course'] as Map<String, dynamic>);
    }

    final dueDateStr = json['due_at'] ?? json['due_date'];

    final rawCompleted = json['is_completed'] ?? json['completed'] ?? json['isCompleted'];
    bool completedVal = false;
    if (rawCompleted is bool) {
      completedVal = rawCompleted;
    } else if (rawCompleted is String) {
      completedVal = rawCompleted.toLowerCase() == 'true' || rawCompleted == '1';
    } else if (rawCompleted is num) {
      completedVal = rawCompleted == 1;
    }

    return Task(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      courseId: json['course_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'assignment',
      dueDate: dueDateStr != null ? DateTime.tryParse(dueDateStr as String) : null,
      isCompleted: completedVal,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      course: courseObj,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (courseId != null) 'course_id': courseId,
      'title': title,
      if (description != null) 'description': description,
      if (type != null) 'type': type,
      if (dueDate != null) 'due_at': dueDate?.toIso8601String(),
      'is_completed': isCompleted,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (course != null) 'courses': course?.toJson(),
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? title,
    String? description,
    String? type,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? createdAt,
    Course? course,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      course: course ?? this.course,
    );
  }
}
