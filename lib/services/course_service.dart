import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';

class CourseService {
  final SupabaseClient _client;

  CourseService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Get all courses for the current user
  Future<List<Course>> getCourses() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('courses')
        .select()
        .eq('user_id', userId)
        .order('course_name', ascending: true);

    return (response as List).map((e) => Course.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get a single course by ID
  Future<Course?> getCourseById(String courseId) async {
    final response = await _client
        .from('courses')
        .select()
        .eq('id', courseId)
        .maybeSingle();

    if (response == null) return null;
    return Course.fromJson(response);
  }

  /// Add a new course
  Future<Course> addCourse({
    required String name,
    String? code,
    String? professor,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final data = {
      'user_id': userId,
      'course_name': name.trim(),
      if (code != null && code.trim().isNotEmpty) 'course_code': code.trim(),
      if (professor != null && professor.trim().isNotEmpty) 'professor': professor.trim(),
    };

    final response = await _client.from('courses').insert(data).select().single();
    return Course.fromJson(response);
  }

  /// Update an existing course
  Future<Course> updateCourse(Course course) async {
    final data = {
      'course_name': course.name.trim(),
      'course_code': course.code?.trim(),
      'professor': course.professor?.trim(),
    };

    final response = await _client
        .from('courses')
        .update(data)
        .eq('id', course.id)
        .select()
        .single();

    return Course.fromJson(response);
  }

  /// Delete a course by ID
  Future<void> deleteCourse(String courseId) async {
    await _client.from('courses').delete().eq('id', courseId);
  }
}