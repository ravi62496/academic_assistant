import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../services/cache_service.dart';
import '../services/course_service.dart';

final courseServiceProvider = Provider<CourseService>((ref) {
  return CourseService();
});

class CourseNotifier extends AsyncNotifier<List<Course>> {
  static const _cacheKey = 'cached_courses';
  final _cacheService = CacheService();

  @override
  Future<List<Course>> build() async {
    final service = ref.watch(courseServiceProvider);

    // 1. Instantly load cached courses if available
    final cached = await _cacheService.getList<Course>(_cacheKey, Course.fromJson);
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }

    // 2. Fetch fresh data from network and update cache
    try {
      final fresh = await service.getCourses();
      await _cacheService.saveList(_cacheKey, fresh, (c) => c.toJson());
      state = AsyncValue.data(fresh);
      return fresh;
    } catch (e) {
      if (cached != null) {
        state = AsyncValue.data(cached);
        return cached;
      }
      rethrow;
    }
  }

  Future<Course> addCourse({
    required String name,
    String? code,
    String? professor,
    String? color,
  }) async {
    final service = ref.read(courseServiceProvider);
    final newCourse = await service.addCourse(
      name: name,
      code: code,
      professor: professor,
    );
    ref.invalidateSelf();
    return newCourse;
  }

  Future<Course> updateCourse(Course course) async {
    final service = ref.read(courseServiceProvider);
    final updated = await service.updateCourse(course);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> deleteCourse(String courseId) async {
    final service = ref.read(courseServiceProvider);
    await service.deleteCourse(courseId);
    ref.invalidateSelf();
  }

  Future<void> loadCourses() async {
    ref.invalidateSelf();
  }
}

final coursesProvider = AsyncNotifierProvider<CourseNotifier, List<Course>>(
  CourseNotifier.new,
);
