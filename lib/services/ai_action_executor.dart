import 'package:intl/intl.dart';
import '../models/course.dart';
import 'course_service.dart';
import 'timetable_service.dart';

class AiActionExecutor {
  final CourseService _courseService;
  final TimetableService _timetableService;

  AiActionExecutor({
    CourseService? courseService,
    TimetableService? timetableService,
  })  : _courseService = courseService ?? CourseService(),
        _timetableService = timetableService ?? TimetableService();

  /// Executes a concrete AI tool action using existing CourseService and TimetableService methods
  Future<String> execute(String toolName, Map<String, dynamic> input) async {
    switch (toolName) {
      case 'add_course':
        final name = (input['name'] ?? '').toString();
        final code = input['code']?.toString();
        final professor = input['professor']?.toString();

        final course = await _courseService.addCourse(
          name: name,
          code: code,
          professor: professor,
        );
        return 'Added course "${course.name}"${course.code != null ? ' (${course.code})' : ''}.';

      case 'update_course':
        final courseId = (input['course_id'] ?? '').toString();
        final existing = await _courseService.getCourseById(courseId);
        if (existing == null) {
          throw Exception('Course with ID "$courseId" not found.');
        }

        final newName = input['name']?.toString() ?? existing.name;
        final newCode = input.containsKey('code') ? input['code']?.toString() : existing.code;
        final newProf = input.containsKey('professor') ? input['professor']?.toString() : existing.professor;

        final updated = existing.copyWith(
          name: newName,
          code: newCode,
          professor: newProf,
        );
        await _courseService.updateCourse(updated);
        return 'Updated course "${updated.name}".';

      case 'delete_course':
        final courseId = (input['course_id'] ?? '').toString();
        await _courseService.deleteCourse(courseId);
        return 'Deleted course successfully.';

      case 'add_class':
        final courseId = (input['course_id'] ?? '').toString();
        final dayOfWeek = (input['day_of_week'] as num).toInt();
        final startTime = (input['start_time'] ?? '').toString();
        final endTime = (input['end_time'] ?? '').toString();
        final room = input['room']?.toString();

        await _timetableService.addClass(
          courseId: courseId,
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          room: room,
        );
        return 'Added class slot for ${_getDayName(dayOfWeek)} at $startTime - $endTime.';

      case 'update_class':
        final classId = (input['class_id'] ?? '').toString();
        final existing = await _timetableService.getClassById(classId);
        if (existing == null) {
          throw Exception('Class schedule with ID "$classId" not found.');
        }

        final updated = existing.copyWith(
          courseId: input['course_id']?.toString() ?? existing.courseId,
          dayOfWeek: input['day_of_week'] != null ? (input['day_of_week'] as num).toInt() : existing.dayOfWeek,
          startTime: input['start_time']?.toString() ?? existing.startTime,
          endTime: input['end_time']?.toString() ?? existing.endTime,
          room: input.containsKey('room') ? input['room']?.toString() : existing.room,
        );

        await _timetableService.updateClass(updated);
        return 'Updated class schedule slot.';

      case 'delete_class':
        final classId = (input['class_id'] ?? '').toString();
        await _timetableService.deleteClass(classId);
        return 'Deleted class schedule slot.';

      case 'add_override':
        final classId = (input['class_id'] ?? '').toString();
        final rawDate = (input['date'] ?? '').toString();
        final date = _normalizeDateString(rawDate);
        final type = (input['type'] ?? 'cancelled').toString();
        final newStartTime = input['new_start_time']?.toString();
        final newEndTime = input['new_end_time']?.toString();
        final newRoom = input['new_room']?.toString();
        final newDayOfWeek = input['new_day_of_week'] != null ? (input['new_day_of_week'] as num).toInt() : null;

        await _timetableService.addOverride(
          classScheduleId: classId,
          overrideDate: date,
          type: type,
          newStartTime: newStartTime,
          newEndTime: newEndTime,
          newRoom: newRoom,
          newDayOfWeek: newDayOfWeek,
        );
        return 'Saved schedule override ($type) for $date.';

      case 'import_schedule_from_image':
        final rawEntries = input['entries'] as List<dynamic>? ?? [];
        if (rawEntries.isEmpty) {
          return 'No classes to import.';
        }

        int importedCount = 0;
        for (final item in rawEntries) {
          final entry = Map<String, dynamic>.from(item as Map);
          final courseName = (entry['course_name'] ?? '').toString().trim();
          if (courseName.isEmpty) continue;

          final courseCode = entry['course_code']?.toString().trim();
          final professor = entry['professor']?.toString().trim();
          final dayOfWeek = (entry['day_of_week'] as num? ?? 1).toInt();
          final startTime = (entry['start_time'] ?? '09:00').toString().trim();
          final endTime = (entry['end_time'] ?? '10:00').toString().trim();
          final room = entry['room']?.toString().trim();

          // Fetch fresh courses to check for duplicates
          final courses = await _courseService.getCourses();
          Course? targetCourse;
          for (final c in courses) {
            if (c.name.trim().toLowerCase() == courseName.toLowerCase() ||
                (courseCode != null &&
                    courseCode.isNotEmpty &&
                    c.code != null &&
                    c.code!.trim().toLowerCase() == courseCode.toLowerCase())) {
              targetCourse = c;
              break;
            }
          }

          targetCourse ??= await _courseService.addCourse(
            name: courseName,
            code: courseCode,
            professor: professor,
          );

          await _timetableService.addClass(
            courseId: targetCourse.id,
            dayOfWeek: dayOfWeek,
            startTime: startTime,
            endTime: endTime,
            room: room,
          );
          importedCount++;
        }

        return 'Successfully imported $importedCount class schedules.';

      default:
        throw Exception('Unknown tool action: $toolName');
    }
  }

  static String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Day $day';
    }
  }

  static String _normalizeDateString(String input) {
    final lower = input.trim().toLowerCase();
    final now = DateTime.now();

    if (lower == 'today') {
      return DateFormat('yyyy-MM-dd').format(now);
    } else if (lower == 'tomorrow') {
      return DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
    } else if (lower == 'yesterday') {
      return DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    }

    // Try parsing ISO date
    final parsed = DateTime.tryParse(input.trim());
    if (parsed != null) {
      return DateFormat('yyyy-MM-dd').format(parsed);
    }

    return input.trim();
  }
}
