import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class TaskService {
  final SupabaseClient _client;

  TaskService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Get all tasks for the current user
  Future<List<Task>> getTasks({bool? isCompleted}) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      var query = _client
          .from('tasks')
          .select('*, courses(*)')
          .eq('user_id', userId);

      if (isCompleted != null) {
        query = query.eq('is_completed', isCompleted);
      }

      final response = await query.order('due_at', ascending: true, nullsFirst: false);
      return (response as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      try {
        var query = _client.from('tasks').select().eq('user_id', userId);
        if (isCompleted != null) {
          try {
            query = query.eq('is_completed', isCompleted);
          } catch (_) {
            query = query.eq('completed', isCompleted);
          }
        }
        final response = await query;
        return (response as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
      } catch (err) {
        debugPrint('Error getting tasks: $err');
        return [];
      }
    }
  }

  /// Get tasks for a specific course
  Future<List<Task>> getTasksForCourse(String courseId) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('tasks')
          .select('*, courses(*)')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .order('due_at', ascending: true, nullsFirst: false);

      return (response as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      try {
        final response = await _client
            .from('tasks')
            .select()
            .eq('user_id', userId)
            .eq('course_id', courseId);
        return (response as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
      } catch (err) {
        debugPrint('Error getting tasks for course: $err');
        return [];
      }
    }
  }

  /// Add a new task with candidate schema fallbacks (including 'type' field)
  Future<Task> addTask({
    required String title,
    String? description,
    String? courseId,
    DateTime? dueDate,
    String? type,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated. Please log in again.');

    final baseData = <String, dynamic>{
      'user_id': userId,
      'title': title.trim(),
      'type': type ?? 'assignment',
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
    };

    // Candidate payloads in order of preference
    final candidatePayloads = <Map<String, dynamic>>[];

    if (dueDate != null) {
      final isoDate = dueDate.toIso8601String();
      candidatePayloads.add({...baseData, 'due_at': isoDate});
      candidatePayloads.add({...baseData, 'due_date': isoDate});
      candidatePayloads.add({...baseData, 'deadline': isoDate});
    }

    // Candidate without date column
    candidatePayloads.add({...baseData});

    // Try alternate type values if 'assignment' is constrained
    final altType1 = Map<String, dynamic>.from(baseData)..['type'] = 'task';
    candidatePayloads.add(altType1);

    final altType2 = Map<String, dynamic>.from(baseData)..['type'] = 'general';
    candidatePayloads.add(altType2);

    // Try without 'type' column
    final noTypeData = Map<String, dynamic>.from(baseData)..remove('type');
    candidatePayloads.add(noTypeData);

    // Try minimal payload without course_id
    if (baseData.containsKey('course_id')) {
      final noCourseData = Map<String, dynamic>.from(baseData)..remove('course_id');
      candidatePayloads.add(noCourseData);
    }

    dynamic response;
    Object? lastError;

    for (final payload in candidatePayloads) {
      // 1. Try with courses join
      try {
        response = await _client
            .from('tasks')
            .insert(payload)
            .select('*, courses(*)')
            .single();
        lastError = null;
        break;
      } catch (e1) {
        debugPrint('Insert with join notice ($payload): $e1');
        // 2. Try without courses join
        try {
          response = await _client
              .from('tasks')
              .insert(payload)
              .select()
              .single();
          lastError = null;
          break;
        } catch (e2) {
          debugPrint('Insert without join notice ($payload): $e2');
          lastError = e2;
        }
      }
    }

    if (response == null) {
      final errStr = lastError?.toString() ?? 'Failed to create task';
      if (errStr.contains('42501') || errStr.contains('row-level security')) {
        throw Exception('Supabase Permission Error (42501): RLS INSERT policy missing for "tasks" table.');
      }
      throw Exception(errStr);
    }

    return Task.fromJson(response as Map<String, dynamic>);
  }

  /// Update an existing task with candidate schema fallbacks
  Future<Task> updateTask(Task task) async {
    final baseData = <String, dynamic>{
      'title': task.title.trim(),
      if (task.description != null) 'description': task.description?.trim(),
      if (task.courseId != null) 'course_id': task.courseId,
      if (task.type != null) 'type': task.type,
    };

    final candidatePayloads = <Map<String, dynamic>>[];

    if (task.dueDate != null) {
      final isoDate = task.dueDate!.toIso8601String();
      candidatePayloads.add({...baseData, 'due_at': isoDate, 'is_completed': task.isCompleted});
      candidatePayloads.add({...baseData, 'due_date': isoDate, 'completed': task.isCompleted});
      candidatePayloads.add({...baseData, 'due_at': isoDate});
      candidatePayloads.add({...baseData, 'due_date': isoDate});
    } else {
      candidatePayloads.add({...baseData, 'is_completed': task.isCompleted});
      candidatePayloads.add({...baseData, 'completed': task.isCompleted});
      candidatePayloads.add({...baseData});
    }

    dynamic response;
    Object? lastError;

    for (final payload in candidatePayloads) {
      try {
        response = await _client
            .from('tasks')
            .update(payload)
            .eq('id', task.id)
            .select()
            .single();
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
      }
    }

    if (response == null) {
      throw lastError ?? Exception('Failed to update task');
    }

    return Task.fromJson(response as Map<String, dynamic>);
  }

  /// Toggle task completed state
  Future<void> toggleTaskCompleted(String taskId, bool isCompleted) async {
    try {
      await _client
          .from('tasks')
          .update({'is_completed': isCompleted})
          .eq('id', taskId);
    } catch (e) {
      try {
        await _client
            .from('tasks')
            .update({'completed': isCompleted})
            .eq('id', taskId);
      } catch (err) {
        debugPrint('Error toggling task completion: $err');
      }
    }
  }

  /// Delete a task by ID
  Future<void> deleteTask(String taskId) async {
    try {
      await _client.from('tasks').delete().eq('id', taskId);
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }
}
