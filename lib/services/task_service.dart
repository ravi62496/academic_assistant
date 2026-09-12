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

    var query = _client
        .from('tasks')
        .select('*, courses(*)')
        .eq('user_id', userId);

    if (isCompleted != null) {
      query = query.eq('is_completed', isCompleted);
    }

    final response = await query.order('due_at', ascending: true, nullsFirst: false);

    return (response as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get tasks for a specific course
  Future<List<Task>> getTasksForCourse(String courseId) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('tasks')
        .select('*, courses(*)')
        .eq('user_id', userId)
        .eq('course_id', courseId)
        .order('due_at', ascending: true, nullsFirst: false);

    return (response as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Add a new task
  Future<Task> addTask({
    required String title,
    String? description,
    String? courseId,
    DateTime? dueDate,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final data = {
      'user_id': userId,
      'title': title.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
      if (dueDate != null) 'due_at': dueDate.toIso8601String(),
      'is_completed': false,
    };

    final response = await _client
        .from('tasks')
        .insert(data)
        .select('*, courses(*)')
        .single();

    return Task.fromJson(response);
  }

  /// Update an existing task
  Future<Task> updateTask(Task task) async {
    final data = {
      'title': task.title.trim(),
      'description': task.description?.trim(),
      'course_id': task.courseId,
      'due_at': task.dueDate?.toIso8601String(),
      'is_completed': task.isCompleted,
    };

    final response = await _client
        .from('tasks')
        .update(data)
        .eq('id', task.id)
        .select('*, courses(*)')
        .single();

    return Task.fromJson(response);
  }

  /// Toggle task completed state
  Future<void> toggleTaskCompleted(String taskId, bool isCompleted) async {
    await _client
        .from('tasks')
        .update({'is_completed': isCompleted})
        .eq('id', taskId);
  }

  /// Delete a task by ID
  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }
}
