import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import '../services/course_service.dart';

final courseServiceProvider = Provider<CourseService>((ref) {
  return CourseService();
});

class CourseNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    final service = ref.watch(courseServiceProvider);
    return service.getCourses();
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
