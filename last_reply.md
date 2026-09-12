# Instructions for Fixing Add Course and Add Class Issues

Here are the exact files, code modifications, and reasons why these changes are necessary to fix adding courses and classes:

---

### 1. `lib/services/timetable_service.dart`

#### **What to change:**
Change `.select('*, courses(*)')` to `.select()` in both `addClass()` and `updateClass()`.

```dart
// In addClass():
final response = await _client
    .from('class_schedules')
    .insert(data)
    .select() // <-- Changed from .select('*, courses(*)')
    .single();

// In updateClass():
final response = await _client
    .from('class_schedules')
    .update(data)
    .eq('id', classSchedule.id)
    .select() // <-- Changed from .select('*, courses(*)')
    .single();
```

Also, in `getOverridesForDate()` and `addOverride()`, ensure the column name matches Supabase:
```dart
// In getOverridesForDate():
.eq('override_date', overrideDate) // Use 'override_date' instead of 'date'

// In addOverride():
'override_date': overrideDate,
```

#### **Why:**
1. **Embedded Joins on Mutation:** In Supabase (PostgREST), requesting embedded foreign keys (`courses(*)`) directly on an `INSERT` or `UPDATE` operation often fails or returns `null` because PostgREST cannot always resolve relational joins during mutations. Changing this to `.select()` returns the inserted row cleanly. The Riverpod provider then calls `ref.invalidateSelf()`, triggering `getClasses()` which correctly fetches joined course details.
2. **Column Mis-match in Overrides:** In Supabase, the table column is named `override_date`. Querying `'date'` causes PostgreSQL error `42703 (undefined column)`.

---

### 2. `lib/models/schedule_override.dart`

#### **What to change:**
Update `fromJson` and `toJson` to handle both `override_date` and `date`:

```dart
factory ScheduleOverride.fromJson(Map<String, dynamic> json) {
  return ScheduleOverride(
    id: json['id'] as String,
    userId: json['user_id'] as String? ?? '',
    classScheduleId: json['class_schedule_id'] as String? ?? '',
    overrideDate: json['override_date'] as String? ?? json['date'] as String? ?? '',
    type: json['type'] as String? ?? 'cancelled',
    newStartTime: json['new_start_time'] as String?,
    newEndTime: json['new_end_time'] as String?,
    newRoom: json['new_room'] as String?,
    newDayOfWeek: (json['new_day_of_week'] as num?)?.toInt(),
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
  );
}

Map<String, dynamic> toJson() {
  return {
    'id': id,
    'user_id': userId,
    'class_schedule_id': classScheduleId,
    'override_date': overrideDate,
    'type': type,
    if (newStartTime != null) 'new_start_time': newStartTime,
    if (newEndTime != null) 'new_end_time': newEndTime,
    if (newRoom != null) 'new_room': newRoom,
    if (newDayOfWeek != null) 'new_day_of_week': newDayOfWeek,
    if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
  };
}
```

#### **Why:**
Prevents `NullPointerException` or serialization errors when converting JSON records fetched from Supabase.

---

### 3. `lib/screens/add_class_screen.dart`

#### **What to change:**
Ensure `_selectedCourseId` is safely populated before building the dropdown and saving:

```dart
// Pre-select first course if not already set
_selectedCourseId ??= courses.first.id;

// Ensure selected item exists in list
final validCourseId = courses.any((c) => c.id == _selectedCourseId)
    ? _selectedCourseId
    : courses.first.id;
```

#### **Why:**
If `_selectedCourseId` is `null` or points to an ID not present in the user's `courses` list, submitting the form triggers a validation error (`Please select a course`) or an assertion error in Flutter's `DropdownButtonFormField`.

---

### Summary Table

| File | Change | Why |
|---|---|---|
| `lib/services/timetable_service.dart` | Replace `.select('*, courses(*)')` with `.select()` on `insert()`/`update()` | Prevents PostgREST relational join failures on insert. |
| `lib/services/timetable_service.dart` | Replace `'date'` with `'override_date'` in `schedule_overrides` queries | Matches Supabase table schema column name. |
| `lib/models/schedule_override.dart` | Map `'override_date'` field in JSON | Ensures safe model deserialization. |
| `lib/screens/add_class_screen.dart` | Fallback `_selectedCourseId` to first course ID | Guarantees a valid course ID is passed when adding a class. |
