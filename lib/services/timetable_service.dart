import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_schedule.dart';
import '../models/schedule_override.dart';

class TimetableService {
  final SupabaseClient _client;

  TimetableService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Get all recurring classes for the user
  Future<List<ClassSchedule>> getClasses() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('class_schedules')
        .select('*, courses(*)')
        .eq('user_id', userId)
        .order('day_of_week', ascending: true)
        .order('start_time', ascending: true);

    return (response as List).map((e) => ClassSchedule.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get recurring classes for a specific day of week (1 = Mon ... 7 = Sun)
  Future<List<ClassSchedule>> getClassesForDay(int dayOfWeek) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('class_schedules')
        .select('*, courses(*)')
        .eq('user_id', userId)
        .eq('day_of_week', dayOfWeek)
        .order('start_time', ascending: true);

    return (response as List).map((e) => ClassSchedule.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Get single class schedule by ID
  Future<ClassSchedule?> getClassById(String classScheduleId) async {
    final response = await _client
        .from('class_schedules')
        .select('*, courses(*)')
        .eq('id', classScheduleId)
        .maybeSingle();

    if (response == null) return null;
    return ClassSchedule.fromJson(response);
  }

  /// Add a new recurring class schedule
  Future<ClassSchedule> addClass({
    required String courseId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final data = {
      'user_id': userId,
      'course_id': courseId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      if (room != null && room.trim().isNotEmpty) 'room': room.trim(),
    };

    final response = await _client
        .from('class_schedules')
        .insert(data)
        .select('*, courses(*)')
        .single();

    return ClassSchedule.fromJson(response);
  }

  /// Update an existing class schedule
  Future<ClassSchedule> updateClass(ClassSchedule classSchedule) async {
    final data = {
      'course_id': classSchedule.courseId,
      'day_of_week': classSchedule.dayOfWeek,
      'start_time': classSchedule.startTime,
      'end_time': classSchedule.endTime,
      'room': classSchedule.room?.trim(),
    };

    final response = await _client
        .from('class_schedules')
        .update(data)
        .eq('id', classSchedule.id)
        .select('*, courses(*)')
        .single();

    return ClassSchedule.fromJson(response);
  }

  /// Delete a class schedule
  Future<void> deleteClass(String classScheduleId) async {
    await _client.from('class_schedules').delete().eq('id', classScheduleId);
  }

  /// Get schedule overrides for a specific date (YYYY-MM-DD)
  Future<List<ScheduleOverride>> getOverridesForDate(String overrideDate) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    final response = await _client
        .from('schedule_overrides')
        .select()
        .eq('user_id', userId)
        .eq('date', overrideDate);

    return (response as List).map((e) => ScheduleOverride.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Add or update a schedule override
  Future<ScheduleOverride> addOverride({
    required String classScheduleId,
    required String overrideDate,
    required String type, // "cancelled" or "rescheduled"
    String? newStartTime,
    String? newEndTime,
    String? newRoom,
    int? newDayOfWeek,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final data = <String, dynamic>{
      'user_id': userId,
      'class_schedule_id': classScheduleId,
      'date': overrideDate,
      'type': type,
      if (newStartTime != null) 'new_start_time': newStartTime,
      if (newEndTime != null) 'new_end_time': newEndTime,
      if (newRoom != null) 'new_room': newRoom,
      if (newDayOfWeek != null) 'new_day_of_week': newDayOfWeek,
    };

    final response = await _client
        .from('schedule_overrides')
        .upsert(data, onConflict: 'user_id,class_schedule_id,date')
        .select()
        .single();

    return ScheduleOverride.fromJson(response);
  }

  /// Delete a schedule override by ID
  Future<void> deleteOverride(String overrideId) async {
    await _client.from('schedule_overrides').delete().eq('id', overrideId);
  }

  /// Engine function: Merges recurring class schedules with overrides for a specific date
  Future<List<ClassSchedule>> getScheduleForDate(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayOfWeek = date.weekday; // 1 = Monday, 7 = Sunday

    // 1 & 2. Fetch recurring classes for this weekday AND overrides concurrently
    final results = await Future.wait([
      getClassesForDay(dayOfWeek),
      getOverridesForDate(dateStr),
    ]);

    final recurringClasses = results[0] as List<ClassSchedule>;
    final overrides = results[1] as List<ScheduleOverride>;
    final overrideMap = {for (var o in overrides) o.classScheduleId: o};

    final List<ClassSchedule> effectiveClasses = [];

    for (final cs in recurringClasses) {
      final override = overrideMap[cs.id];
      if (override != null) {
        if (override.type == 'cancelled') {
          // Excluded from active schedule for this date
          continue;
        } else if (override.type == 'rescheduled') {
          // Use rescheduled attributes
          effectiveClasses.add(cs.copyWith(
            startTime: override.newStartTime ?? cs.startTime,
            endTime: override.newEndTime ?? cs.endTime,
            room: override.newRoom ?? cs.room,
          ));
        }
      } else {
        effectiveClasses.add(cs);
      }
    }

    // 3. Handle overrides that rescheduled classes from another day TO this date
    final otherOverrides = overrides.where((o) => !recurringClasses.any((cs) => cs.id == o.classScheduleId)).toList();
    if (otherOverrides.isNotEmpty) {
      final baseClasses = await Future.wait(
        otherOverrides.map((o) => getClassById(o.classScheduleId)),
      );
      for (int i = 0; i < otherOverrides.length; i++) {
        final o = otherOverrides[i];
        final baseCs = baseClasses[i];
        if (o.type == 'rescheduled' && baseCs != null) {
          effectiveClasses.add(baseCs.copyWith(
            startTime: o.newStartTime ?? baseCs.startTime,
            endTime: o.newEndTime ?? baseCs.endTime,
            room: o.newRoom ?? baseCs.room,
          ));
        }
      }
    }

    // 4. Sort effective classes by start time
    effectiveClasses.sort((a, b) => a.startTime.compareTo(b.startTime));
    return effectiveClasses;
  }

  /// Listen to real-time class updates (cancellations, postponements) from Supabase
  Stream<List<Map<String, dynamic>>> streamClassUpdates() {
    final userId = _currentUserId;
    if (userId == null) return const Stream.empty();

    return _client
        .from('class_updates')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId);
  }
}
