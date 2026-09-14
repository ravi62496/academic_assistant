import 'course.dart';

class ClassSchedule {
  final String id;
  final String userId;
  final String courseId;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final String startTime; // "HH:mm" or "HH:mm:ss"
  final String endTime; // "HH:mm" or "HH:mm:ss"
  final String? room;
  final DateTime? createdAt;
  final Course? course;

  ClassSchedule({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
    this.createdAt,
    this.course,
  });

  factory ClassSchedule.fromJson(Map<String, dynamic> json) {
    Course? courseObj;
    if (json['courses'] != null && json['courses'] is Map<String, dynamic>) {
      courseObj = Course.fromJson(json['courses'] as Map<String, dynamic>);
    } else if (json['course'] != null && json['course'] is Map<String, dynamic>) {
      courseObj = Course.fromJson(json['course'] as Map<String, dynamic>);
    }

    return ClassSchedule(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      courseId: json['course_id'] as String? ?? '',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 1,
      startTime: json['start_time'] as String? ?? '00:00',
      endTime: json['end_time'] as String? ?? '00:00',
      room: json['room'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      course: courseObj,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'course_id': courseId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      if (room != null) 'room': room,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (course != null) 'courses': course?.toJson(),
    };
  }

  ClassSchedule copyWith({
    String? id,
    String? userId,
    String? courseId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    DateTime? createdAt,
    Course? course,
  }) {
    return ClassSchedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      createdAt: createdAt ?? this.createdAt,
      course: course ?? this.course,
    );
  }
}
