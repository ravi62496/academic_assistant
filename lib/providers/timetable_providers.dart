import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_schedule.dart';
import '../services/cache_service.dart';
import '../services/timetable_service.dart';

final timetableServiceProvider = Provider<TimetableService>((ref) {
  return TimetableService();
});

class TimetableNotifier extends AsyncNotifier<List<ClassSchedule>> {
  static const _cacheKey = 'cached_classes';
  final _cacheService = CacheService();

  @override
  Future<List<ClassSchedule>> build() async {
    final service = ref.watch(timetableServiceProvider);

    // 1. Instantly load cached class schedules if available
    final cached = await _cacheService.getList<ClassSchedule>(_cacheKey, ClassSchedule.fromJson);
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }

    // 2. Fetch fresh class schedules from network and update cache
    try {
      final fresh = await service.getClasses();
      await _cacheService.saveList(_cacheKey, fresh, (cs) => cs.toJson());
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

  final cacheService = CacheService();
  final cacheKey = 'cached_schedule_${normalizedDate.year}_${normalizedDate.month}_${normalizedDate.day}';

  final cached = await cacheService.getList<ClassSchedule>(cacheKey, ClassSchedule.fromJson);

  final service = ref.watch(timetableServiceProvider);

  try {
    final fresh = await service.getScheduleForDate(normalizedDate);
    await cacheService.saveList(cacheKey, fresh, (cs) => cs.toJson());
    return fresh;
  } catch (e) {
    if (cached != null) {
      return cached;
    }
    rethrow;
  }
});

/// StreamProvider listening to real-time class updates from Supabase
final classUpdatesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(timetableServiceProvider);
  return service.streamClassUpdates();
});

