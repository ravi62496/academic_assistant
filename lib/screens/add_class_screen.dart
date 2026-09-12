import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/class_schedule.dart';
import '../models/course.dart';
import '../providers/course_providers.dart';
import '../providers/timetable_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_utils.dart';

class AddClassScreen extends ConsumerStatefulWidget {
  final ClassSchedule? classSchedule;

  const AddClassScreen({super.key, this.classSchedule});

  @override
  ConsumerState<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends ConsumerState<AddClassScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCourseId;
  int _selectedDayOfWeek = 1; // 1 = Mon
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  final _roomController = TextEditingController();
  bool _isSaving = false;

  static const List<String> _daysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.classSchedule != null) {
      final cs = widget.classSchedule!;
      _selectedCourseId = cs.courseId;
      _selectedDayOfWeek = cs.dayOfWeek;
      _roomController.text = cs.room ?? '';
      _startTime = _parseTime(cs.startTime);
      _endTime = _parseTime(cs.endTime);
    }
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_endTime.hour < picked.hour ||
            (_endTime.hour == picked.hour && _endTime.minute <= picked.minute)) {
          _endTime = TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: _endTime);
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCourseId == null) {
      SnackbarUtils.showError(context, 'Please select a course.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(timetableProvider.notifier);
      final startStr = _formatTimeOfDay(_startTime);
      final endStr = _formatTimeOfDay(_endTime);

      if (widget.classSchedule == null) {
        await notifier.addClass(
          courseId: _selectedCourseId!,
          dayOfWeek: _selectedDayOfWeek,
          startTime: startStr,
          endTime: endStr,
          room: _roomController.text.trim(),
        );
        if (mounted) SnackbarUtils.showSuccess(context, 'Class schedule added');
      } else {
        await notifier.updateClass(
          widget.classSchedule!.copyWith(
            courseId: _selectedCourseId,
            dayOfWeek: _selectedDayOfWeek,
            startTime: startStr,
            endTime: endStr,
            room: _roomController.text.trim(),
          ),
        );
        if (mounted) SnackbarUtils.showSuccess(context, 'Class schedule updated');
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final isEditing = widget.classSchedule != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Class Schedule' : 'Add Class Schedule',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
      ),
      body: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_outlined, size: 54, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Courses Found',
                      style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please add a course first before scheduling a recurring class.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),
            );
          }

          _selectedCourseId ??= courses.first.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course Selection
                  Text(
                    'Select Subject / Course',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: courses.any((c) => c.id == _selectedCourseId)
                        ? _selectedCourseId
                        : courses.first.id,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    items: courses.map((Course course) {
                      return DropdownMenuItem<String>(
                        value: course.id,
                        child: Text(
                          course.code != null && course.code!.isNotEmpty
                              ? '${course.name} (${course.code})'
                              : course.name,
                          style: GoogleFonts.plusJakartaSans(fontSize: 14.5),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCourseId = val),
                  ),

                  const SizedBox(height: 24),

                  // Tactile Day Choice Chips
                  Text(
                    'Day of Week',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (i) {
                      final dayNum = i + 1;
                      final isSelected = dayNum == _selectedDayOfWeek;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: InkWell(
                            onTap: () => setState(() => _selectedDayOfWeek = dayNum),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _daysShort[i],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 24),

                  // Tactile Time Pickers
                  Text(
                    'Class Schedule Time',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickStartTime,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Start Time',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _startTime.format(context),
                                  style: AppTheme.monoTimeStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickEndTime,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time_filled, size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'End Time',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _endTime.format(context),
                                  style: AppTheme.monoTimeStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Room / Location
                  Text(
                    'Classroom / Location',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Science Building, Room 102',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),

                  const SizedBox(height: 36),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEditing ? 'Save Changes' : 'Add Class Schedule',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
