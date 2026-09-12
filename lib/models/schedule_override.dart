class ScheduleOverride {
  final String id;
  final String userId;
  final String classScheduleId;
  final String overrideDate; // YYYY-MM-DD format
  final String type; // "cancelled" or "rescheduled"
  final String? newStartTime;
  final String? newEndTime;
  final String? newRoom;
  final int? newDayOfWeek;
  final DateTime? createdAt;

  ScheduleOverride({
    required this.id,
    required this.userId,
    required this.classScheduleId,
    required this.overrideDate,
    required this.type,
    this.newStartTime,
    this.newEndTime,
    this.newRoom,
    this.newDayOfWeek,
    this.createdAt,
  });

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) {
    return ScheduleOverride(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      classScheduleId: json['class_schedule_id'] as String? ?? '',
      overrideDate: json['date'] as String? ?? '',
      type: json['type'] as String? ?? 'cancelled',
      newStartTime: json['new_start_time'] as String?,
      newEndTime: json['new_end_time'] as String?,
      newRoom: json['new_room'] as String?,
      newDayOfWeek: (json['new_day_of_week'] as num?)?.toInt(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'class_schedule_id': classScheduleId,
      'date': overrideDate,
      'type': type,
      if (newStartTime != null) 'new_start_time': newStartTime,
      if (newEndTime != null) 'new_end_time': newEndTime,
      if (newRoom != null) 'new_room': newRoom,
      if (newDayOfWeek != null) 'new_day_of_week': newDayOfWeek,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
    };
  }

  ScheduleOverride copyWith({
    String? id,
    String? userId,
    String? classScheduleId,
    String? overrideDate,
    String? type,
    String? newStartTime,
    String? newEndTime,
    String? newRoom,
    int? newDayOfWeek,
    DateTime? createdAt,
  }) {
    return ScheduleOverride(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      classScheduleId: classScheduleId ?? this.classScheduleId,
      overrideDate: overrideDate ?? this.overrideDate,
      type: type ?? this.type,
      newStartTime: newStartTime ?? this.newStartTime,
      newEndTime: newEndTime ?? this.newEndTime,
      newRoom: newRoom ?? this.newRoom,
      newDayOfWeek: newDayOfWeek ?? this.newDayOfWeek,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
