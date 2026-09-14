import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/class_schedule.dart';
import '../models/task.dart';
import '../providers/course_providers.dart';
import '../providers/navigation_providers.dart';
import '../providers/task_providers.dart';
import '../providers/timetable_providers.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/class_action_bottom_sheet.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(timetableProvider);
    ref.invalidate(coursesProvider);
    ref.invalidate(tasksProvider);
    _entranceController.reset();
    _entranceController.forward();
    if (mounted) {
      SnackbarUtils.showSuccess(context, 'Dashboard refreshed');
    }
  }

  int _timeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return 0;
    try {
      final clean = timeStr.trim();
      final upper = clean.toUpperCase();
      final isPM = upper.contains('PM');
      final isAM = upper.contains('AM');
      final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digits.split(':');
      if (parts.isEmpty || parts[0].isEmpty) return 0;
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : 0;
      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  String _formatTimeDisplay(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      final minutes = _timeToMinutes(timeStr);
      final hour24 = minutes ~/ 60;
      final min = minutes % 60;
      final period = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final minStr = min.toString().padLeft(2, '0');
      return '$hour12:$minStr $period';
    } catch (_) {
      return timeStr;
    }
  }

  ClassSchedule? _computeCurrentClass(List<ClassSchedule> todayClasses) {
    if (todayClasses.isEmpty) return null;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (final cs in todayClasses) {
      final start = _timeToMinutes(cs.startTime);
      final end = _timeToMinutes(cs.endTime);
      if (currentMinutes >= start && currentMinutes < end) {
        return cs;
      }
    }
    return null;
  }

  ClassSchedule? _computeNextClass(List<ClassSchedule> todayClasses) {
    if (todayClasses.isEmpty) return null;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    // Check if a class is in progress first
    final currentClass = _computeCurrentClass(todayClasses);
    if (currentClass != null) return currentClass;

    for (final cs in todayClasses) {
      final startMinutes = _timeToMinutes(cs.startTime);
      if (startMinutes > currentMinutes) {
        return cs;
      }
    }
    return null;
  }

  double _calculateClassProgress(ClassSchedule cs) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final start = _timeToMinutes(cs.startTime);
    final end = _timeToMinutes(cs.endTime);
    if (end <= start) return 1.0;
    final progress = (currentMinutes - start) / (end - start);
    return progress.clamp(0.0, 1.0);
  }

  String _getTimeBadge(ClassSchedule cs) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeToMinutes(cs.startTime);
    final endMinutes = _timeToMinutes(cs.endTime);

    if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
      final remaining = endMinutes - currentMinutes;
      if (remaining < 60) {
        return '$remaining min left';
      } else {
        final h = remaining ~/ 60;
        final m = remaining % 60;
        return m > 0 ? '$h hrs $m mins left' : '$h hrs left';
      }
    } else if (currentMinutes < startMinutes) {
      final diff = startMinutes - currentMinutes;
      if (diff < 60) {
        return 'Starts in $diff min';
      } else {
        final hours = diff ~/ 60;
        final mins = diff % 60;
        return mins > 0 ? 'Starts in ${hours}h ${mins}m' : 'Starts in ${hours}h';
      }
    }
    return 'Completed today';
  }

  bool _isClassCompleted(ClassSchedule cs) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes >= _timeToMinutes(cs.endTime);
  }

  bool _isClassInProgress(ClassSchedule cs) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final start = _timeToMinutes(cs.startTime);
    final end = _timeToMinutes(cs.endTime);
    return currentMinutes >= start && currentMinutes < end;
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDueDate;
    TimeOfDay? selectedDueTime;
    String? selectedCourseId;
    bool isSaving = false;

    final coursesAsync = ref.read(coursesProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add New Task',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close task dialog',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Task Title (e.g. Read Chapter 4)',
                        prefixIcon: Icon(Icons.check_circle_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        hintText: 'Notes / Details (optional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    coursesAsync.when(
                      data: (courses) {
                        if (courses.isEmpty) return const SizedBox.shrink();
                        return DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedCourseId,
                          decoration: const InputDecoration(
                            hintText: 'Select Course (optional)',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          items: courses.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                '${c.code != null ? "${c.code} - " : ""}${c.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setModalState(() => selectedCourseId = val),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 1)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedDate != null) {
                              setModalState(() => selectedDueDate = pickedDate);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            selectedDueDate == null
                                ? 'Due Date'
                                : DateFormat('MMM d').format(selectedDueDate!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: ctx,
                              initialTime: selectedDueTime ?? TimeOfDay.now(),
                            );
                            if (pickedTime != null) {
                              setModalState(() => selectedDueTime = pickedTime);
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text(
                            selectedDueTime == null
                                ? 'Due Time'
                                : selectedDueTime!.format(ctx),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              if (title.isEmpty) {
                                SnackbarUtils.showError(ctx, 'Please enter a task title');
                                return;
                              }

                              DateTime? finalDueDate;
                              if (selectedDueDate != null) {
                                final time = selectedDueTime ?? const TimeOfDay(hour: 23, minute: 59);
                                finalDueDate = DateTime(
                                  selectedDueDate!.year,
                                  selectedDueDate!.month,
                                  selectedDueDate!.day,
                                  time.hour,
                                  time.minute,
                                );
                              }

                              setModalState(() => isSaving = true);

                              try {
                                await ref.read(tasksProvider.notifier).addTask(
                                  title: title,
                                  description: descController.text.trim().isEmpty
                                      ? null
                                      : descController.text.trim(),
                                  courseId: selectedCourseId,
                                  dueDate: finalDueDate,
                                );
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  SnackbarUtils.showSuccess(context, 'Task added successfully');
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  SnackbarUtils.showError(ctx, 'Failed to add task: $e');
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setModalState(() => isSaving = false);
                                }
                              }
                            },
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Task'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _authService.displayName;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayScheduleAsync = ref.watch(scheduleForDateProvider(today));
    final tasksAsync = ref.watch(tasksProvider);

    final bool disableAnimations = MediaQuery.of(context).disableAnimations;

    Widget contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Stats Summary Cards
        todayScheduleAsync.when(
          data: (todayClasses) => tasksAsync.when(
            data: (tasks) => _buildQuickStatsSection(context, todayClasses, tasks, isDark),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 24),

        // NEXT / CURRENT CLASS HERO SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Classes Today',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            todayScheduleAsync.maybeWhen(
              data: (classes) => _buildClassStatusChip(classes),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        todayScheduleAsync.when(
          data: (todayClasses) => _buildNextClassHero(context, todayClasses, today, isDark),
          loading: () => _buildLoadingCard(),
          error: (err, st) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading schedule: $err'),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // TODAY'S SCHEDULE (TIMELINE RAIL)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Schedule Timeline',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ref.read(activeTabProvider.notifier).selectTab(1);
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text('Full Timetable'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        todayScheduleAsync.when(
          data: (todayClasses) => _buildTimelineRail(context, todayClasses, today, isDark),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, st) => Text('Error: $err'),
        ),

        const SizedBox(height: 28),

        // UPCOMING TASKS SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Tasks & Deadlines',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  tasksAsync.maybeWhen(
                    data: (tasks) {
                      final pendingCount = tasks.where((t) => !t.isCompleted).length;
                      if (pendingCount == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddTaskDialog(context),
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('Add Task'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        tasksAsync.when(
          data: (tasks) => _buildTasksList(context, tasks, isDark),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, st) => Text('Error loading tasks: $err'),
        ),

        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'Assets/images/Sentry.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
              semanticLabel: 'Academic Assistant Logo',
            ),
            const SizedBox(width: 10),
            Text(
              AppConstants.appName,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppColors.sentryGreen,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddTaskDialog(context),
            icon: const Icon(Icons.add_task_outlined),
            tooltip: 'Add Task',
          ),
          InkWell(
            onTap: _openProfile,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: GoogleFonts.spaceGrotesk(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: disableAnimations
              ? contentColumn
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: contentColumn,
                  ),
                ),
        ),
      ),
    );
  }



  Widget _buildClassStatusChip(List<ClassSchedule> todayClasses) {
    final currentClass = _computeCurrentClass(todayClasses);
    if (currentClass != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'IN PROGRESS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    final nextClass = _computeNextClass(todayClasses);
    if (nextClass != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'UPCOMING',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.secondary,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildQuickStatsSection(
    BuildContext context,
    List<ClassSchedule> todayClasses,
    List<Task> tasks,
    bool isDark,
  ) {
    final totalClasses = todayClasses.length;
    final completedClasses = todayClasses.where((c) => _isClassCompleted(c)).length;
    final pendingTasks = tasks.where((t) => !t.isCompleted).length;

    final inProgress = _computeCurrentClass(todayClasses);
    final nextClass = _computeNextClass(todayClasses);

    // Current Status calculation
    String statusTitle = 'All Classes Done 🎉';
    String statusSubtitle = 'No remaining classes scheduled for today';
    Color statusColor = AppColors.success;
    IconData statusIcon = Icons.check_circle_rounded;
    String statusBadge = 'COMPLETED';

    if (inProgress != null) {
      statusTitle = inProgress.course?.name ?? 'Class in Progress';
      statusSubtitle = '${_getTimeBadge(inProgress)} • ${_formatTimeDisplay(inProgress.startTime)} - ${_formatTimeDisplay(inProgress.endTime)}';
      statusColor = AppColors.primary;
      statusIcon = Icons.play_circle_fill_rounded;
      statusBadge = 'IN PROGRESS';
    } else if (nextClass != null) {
      statusTitle = nextClass.course?.name ?? 'Next Class';
      statusSubtitle = '${_getTimeBadge(nextClass)} • ${_formatTimeDisplay(nextClass.startTime)} - ${_formatTimeDisplay(nextClass.endTime)}';
      statusColor = AppColors.secondary;
      statusIcon = Icons.schedule_rounded;
      statusBadge = 'UPCOMING';
    } else if (totalClasses == 0) {
      statusTitle = 'No Classes Scheduled';
      statusSubtitle = 'Free day! Enjoy your break or study';
      statusColor = AppColors.aiAccent;
      statusIcon = Icons.event_available_rounded;
      statusBadge = 'FREE DAY';
    }

    final double classProgress = totalClasses > 0 ? (completedClasses / totalClasses) : 0.0;

    return Column(
      children: [
        // Top Row: 2 Big Rectangular Cards (Classes Done & Pending Tasks)
        Row(
          children: [
            // Card 1: Classes Done
            Expanded(
              child: _buildBiggerStatCard(
                context,
                title: 'Classes Done',
                value: totalClasses > 0 ? '$completedClasses / $totalClasses' : '0',
                subtitle: totalClasses > 0
                    ? '${(classProgress * 100).toInt()}% completed'
                    : 'No classes today',
                icon: Icons.school_rounded,
                accentColor: AppColors.primary,
                progressValue: totalClasses > 0 ? classProgress : null,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            // Card 2: Pending Tasks
            Expanded(
              child: _buildBiggerStatCard(
                context,
                title: 'Pending Tasks',
                value: '$pendingTasks',
                subtitle: pendingTasks == 0
                    ? 'All caught up!'
                    : '$pendingTasks task${pendingTasks == 1 ? '' : 's'} remaining',
                icon: Icons.task_alt_rounded,
                accentColor: AppColors.warning,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bottom Row: Current Status (Full-width Rectangular Banner Card)
        _buildCurrentStatusCard(
          context,
          statusTitle: statusTitle,
          statusSubtitle: statusSubtitle,
          statusColor: statusColor,
          statusIcon: statusIcon,
          statusBadge: statusBadge,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildBiggerStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    double? progressValue,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.4 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: accentColor.withValues(alpha: 0.15),
                color: accentColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard(
    BuildContext context, {
    required String statusTitle,
    required String statusSubtitle,
    required Color statusColor,
    required IconData statusIcon,
    required String statusBadge,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: isDark ? 0.4 : 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusBadge,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current Status',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  statusTitle,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextClassHero(
      BuildContext context, List<ClassSchedule> todayClasses, DateTime today, bool isDark) {
    final currentClass = _computeCurrentClass(todayClasses);
    final targetClass = currentClass ?? _computeNextClass(todayClasses);

    if (targetClass == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Remaining Classes Today',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'All scheduled classes for today are complete. Time to relax or catch up on tasks!',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isInProgress = currentClass != null;
    final badgeText = _getTimeBadge(targetClass);
    final courseColor = AppColors.getCourseColor(targetClass.courseId);
    final formattedStart = _formatTimeDisplay(targetClass.startTime);
    final formattedEnd = _formatTimeDisplay(targetClass.endTime);

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => ClassActionBottomSheet(
            classSchedule: targetClass,
            targetDate: today,
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isInProgress ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4),
            width: isInProgress ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isInProgress
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isInProgress ? Colors.white : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        badgeText,
                        style: GoogleFonts.plusJakartaSans(
                          color: isInProgress ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    '$formattedStart - $formattedEnd',
                    style: AppTheme.monoTimeStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (isInProgress) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _calculateClassProgress(targetClass),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  color: AppColors.primary,
                  minHeight: 5,
                ),
              ),
            ],

            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: courseColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    targetClass.course?.name ?? 'Class',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (targetClass.course?.code != null && targetClass.course!.code!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: courseColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      targetClass.course!.code!,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: courseColor,
                        fontSize: 12,
                      ),
                    ),
                  ),

                if (targetClass.course?.professor != null &&
                    targetClass.course!.professor!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        targetClass.course!.professor!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                if (targetClass.room != null && targetClass.room!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        targetClass.room!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRail(
      BuildContext context, List<ClassSchedule> todayClasses, DateTime today, bool isDark) {
    if (todayClasses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: const Center(
          child: Text(
            'No classes scheduled for today.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(todayClasses.length, (index) {
        final cs = todayClasses[index];
        final isCompleted = _isClassCompleted(cs);
        final inProgress = _isClassInProgress(cs);
        final isLast = index == todayClasses.length - 1;
        final courseColor = AppColors.getCourseColor(cs.courseId);

        final startFormatted = _formatTimeDisplay(cs.startTime);
        final endFormatted = _formatTimeDisplay(cs.endTime);

        return Stack(
          children: [
            // Timeline continuous vertical line
            Positioned(
              left: 68,
              top: index == 0 ? 18 : 0,
              bottom: isLast ? null : 0,
              height: isLast ? 18 : null,
              child: Container(
                width: 2,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time Column
                  SizedBox(
                    width: 60,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            startFormatted,
                            style: AppTheme.monoTimeStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: inProgress
                                  ? AppColors.primary
                                  : (isCompleted
                                      ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                                      : (isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.lightTextPrimary)),
                            ),
                          ),
                          Text(
                            endFormatted,
                            style: AppTheme.monoTimeStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Timeline node dot
                  SizedBox(
                    width: 18,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14.0),
                      child: Center(
                        child: Container(
                          width: inProgress ? 16 : 12,
                          height: inProgress ? 16 : 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: inProgress
                                ? AppColors.primary
                                : (isCompleted ? AppColors.primary : Colors.white),
                            border: Border.all(
                              color: inProgress
                                  ? AppColors.primary
                                  : (isCompleted
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                              width: inProgress ? 3 : 2,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(
                                  Icons.check,
                                  size: 7,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Content card
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => ClassActionBottomSheet(
                            classSchedule: cs,
                            targetDate: today,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: inProgress
                                ? AppColors.primary
                                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            width: inProgress ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: courseColor,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    cs.course?.name ?? 'Class',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      color: isCompleted
                                          ? AppColors.textSecondary
                                          : (isDark
                                              ? AppColors.darkTextPrimary
                                              : AppColors.lightTextPrimary),
                                    ),
                                  ),
                                ),
                                if (inProgress)
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'NOW',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (cs.course?.code != null && cs.course!.code!.isNotEmpty) ...[
                                  Text(
                                    cs.course!.code!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: courseColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (cs.room != null && cs.room!.isNotEmpty) ...[
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    cs.room!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTasksList(BuildContext context, List<Task> tasks, bool isDark) {
    if (tasks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.task_alt_outlined, color: AppColors.textSecondary, size: 32),
            const SizedBox(height: 8),
            const Text(
              'No tasks or deadlines.',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showAddTaskDialog(context),
              child: const Text('Add your first task'),
            ),
          ],
        ),
      );
    }

    // Sort tasks: pending first (sorted by due date), completed at bottom
    final sortedTasks = List<Task>.from(tasks)..sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return 0;
    });

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedTasks.length,
      separatorBuilder: (ctx, index) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final task = sortedTasks[index];
        final isOverdue = task.dueDate != null &&
            task.dueDate!.isBefore(DateTime.now()) &&
            !task.isCompleted;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOverdue
                  ? AppColors.error.withValues(alpha: 0.5)
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Checkbox(
              value: task.isCompleted,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (val) {
                if (val != null) {
                  ref.read(tasksProvider.notifier).toggleTaskCompleted(task.id, val);
                }
              },
            ),
            title: Text(
              task.title,
              style: GoogleFonts.plusJakartaSans(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: task.isCompleted
                    ? AppColors.textSecondary
                    : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
            subtitle: Row(
              children: [
                if (task.dueDate != null) ...[
                  Icon(
                    Icons.schedule_outlined,
                    size: 13,
                    color: task.isCompleted
                        ? AppColors.textSecondary
                        : (isOverdue ? AppColors.error : AppColors.warning),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOverdue
                        ? 'Overdue • ${DateFormat('MMM d, h:mm a').format(task.dueDate!)}'
                        : 'Due ${DateFormat('EEE, MMM d • h:mm a').format(task.dueDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: task.isCompleted
                          ? AppColors.textSecondary
                          : (isOverdue ? AppColors.error : AppColors.warning),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (task.course != null) ...[
                  if (task.dueDate != null) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.course!.code ?? task.course!.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              tooltip: 'Delete task',
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textSecondary),
              onPressed: () async {
                await ref.read(tasksProvider.notifier).deleteTask(task.id);
                if (context.mounted) {
                  SnackbarUtils.showSuccess(context, 'Task removed');
                }
              },
            ),
          ),
        );
      },
    );
  }



  Widget _buildLoadingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
