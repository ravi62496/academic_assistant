import 'package:flutter/material.dart';

class ClassUpdate {
  final String id;
  final String? userId;
  final String gmailMessageId;
  final String? threadId;
  final String type; // 'quiz', 'exam', 'assignment', 'cancelled', 'postponed', 'rescheduled', 'room_change', 'info'
  final String title;
  final String? course;
  final DateTime? startsAt;
  final DateTime? newStartsAt;
  final String? room;
  final String? sender;
  final double confidence;
  final String status; // 'pending', 'confirmed', 'dismissed', 'done'
  final bool isRead;
  final String? rawSubject;
  final String? rawSnippet;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClassUpdate({
    required this.id,
    this.userId,
    required this.gmailMessageId,
    this.threadId,
    required this.type,
    required this.title,
    this.course,
    this.startsAt,
    this.newStartsAt,
    this.room,
    this.sender,
    this.confidence = 0.5,
    this.status = 'pending',
    this.isRead = false,
    this.rawSubject,
    this.rawSnippet,
    this.createdAt,
    this.updatedAt,
  });

  factory ClassUpdate.fromMap(Map<String, dynamic> m) {
    return ClassUpdate(
      id: m['id'] as String,
      userId: m['user_id'] as String?,
      gmailMessageId: m['gmail_message_id'] as String? ?? '',
      threadId: m['thread_id'] as String?,
      type: m['type'] as String? ?? 'info',
      title: m['title'] as String? ?? 'Class Notice',
      course: m['course'] as String?,
      startsAt: m['starts_at'] != null ? DateTime.tryParse(m['starts_at'])?.toLocal() : null,
      newStartsAt: m['new_starts_at'] != null ? DateTime.tryParse(m['new_starts_at'])?.toLocal() : null,
      room: m['room'] as String?,
      sender: m['sender'] as String?,
      confidence: (m['confidence'] as num?)?.toDouble() ?? 0.5,
      status: m['status'] as String? ?? 'pending',
      isRead: m['is_read'] as bool? ?? false,
      rawSubject: m['raw_subject'] as String?,
      rawSnippet: m['raw_snippet'] as String?,
      createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'])?.toLocal() : null,
      updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'])?.toLocal() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (userId != null) 'user_id': userId,
      'gmail_message_id': gmailMessageId,
      if (threadId != null) 'thread_id': threadId,
      'type': type,
      'title': title,
      if (course != null) 'course': course,
      if (startsAt != null) 'starts_at': startsAt?.toIso8601String(),
      if (newStartsAt != null) 'new_starts_at': newStartsAt?.toIso8601String(),
      if (room != null) 'room': room,
      if (sender != null) 'sender': sender,
      'confidence': confidence,
      'status': status,
      'is_read': isRead,
      if (rawSubject != null) 'raw_subject': rawSubject,
      if (rawSnippet != null) 'raw_snippet': rawSnippet,
    };
  }

  bool get isTask => const ['quiz', 'exam', 'assignment'].contains(type);
  bool get isNotice => const ['cancelled', 'postponed', 'rescheduled', 'room_change'].contains(type);

  String get typeLabel {
    switch (type) {
      case 'quiz':
        return 'Quiz';
      case 'exam':
        return 'Exam';
      case 'assignment':
        return 'Assignment';
      case 'cancelled':
        return 'Cancelled';
      case 'postponed':
        return 'Postponed';
      case 'rescheduled':
        return 'Rescheduled';
      case 'room_change':
        return 'Room Change';
      default:
        return 'Announcement';
    }
  }

  Color get typeColor {
    switch (type) {
      case 'cancelled':
        return Colors.redAccent;
      case 'postponed':
      case 'rescheduled':
        return Colors.amber.shade700;
      case 'room_change':
        return Colors.teal;
      case 'exam':
        return Colors.deepPurpleAccent;
      case 'quiz':
        return Colors.indigoAccent;
      case 'assignment':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'postponed':
      case 'rescheduled':
        return Icons.update_outlined;
      case 'room_change':
        return Icons.meeting_room_outlined;
      case 'exam':
        return Icons.assignment_late_outlined;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'assignment':
        return Icons.assignment_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
