import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_schedule.dart';
import '../services/timetable_service.dart';

final timetableServiceProvider = Provider<TimetableService>((ref) {
  return TimetableService();
});

class TimetableNotifier extends AsyncNotifier<List<ClassSchedule>> {
  @override
  Future<List<ClassSchedule>> build() async {
    final service = ref.watch(timetableServiceProvider);
    return service.getClasses();
  }

  Future<ClassSchedule> addClass({
    required String courseId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
  }) async {
    final service = ref.read(timetableServiceProvider);
    final newClass = await service.addClass(
      courseId: courseId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      room: room,
    );
    ref.invalidateSelf();
    return newClass;
  }

  Future<ClassSchedule> updateClass(ClassSchedule classSchedule) async {
    final service = ref.read(timetableServiceProvider);
    final updated = await service.updateClass(classSchedule);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> deleteClass(String classScheduleId) async {
    final service = ref.read(timetableServiceProvider);
    await service.deleteClass(classScheduleId);
    ref.invalidateSelf();
  }

  Future<void> addOverride({
    required String classScheduleId,
    required String overrideDate,
    required String type,
    String? newStartTime,
    String? newEndTime,
    String? newRoom,
    int? newDayOfWeek,
  }) async {
    final service = ref.read(timetableServiceProvider);
    await service.addOverride(
      classScheduleId: classScheduleId,
      overrideDate: overrideDate,
      type: type,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
      newRoom: newRoom,
      newDayOfWeek: newDayOfWeek,
    );
    ref.invalidateSelf();
  }

  Future<void> loadSchedules() async {
    ref.invalidateSelf();
  }
}

final timetableProvider = AsyncNotifierProvider<TimetableNotifier, List<ClassSchedule>>(
  TimetableNotifier.new,
);

/// FutureProvider for schedule for a specific date using `getScheduleForDate(date)` engine
final scheduleForDateProvider = FutureProvider.family<List<ClassSchedule>, DateTime>((ref, date) async {
  // Normalize date to date-only (midnight) so time component changes don't affect provider key
  final normalizedDate = DateTime(date.year, date.month, date.day);
  // Watch timetableProvider so this recalculates whenever schedules or overrides change
  ref.watch(timetableProvider);
  final service = ref.watch(timetableServiceProvider);
  return service.getScheduleForDate(normalizedDate);
});
