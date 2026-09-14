import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/class_schedule.dart';
import '../providers/timetable_providers.dart';
import '../screens/add_class_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_utils.dart';

class ClassActionBottomSheet extends ConsumerWidget {
  final ClassSchedule classSchedule;
  final DateTime targetDate;

  const ClassActionBottomSheet({
    super.key,
    required this.classSchedule,
    required this.targetDate,
  });

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  void _showRescheduleDialog(BuildContext context, WidgetRef ref) {
    TimeOfDay startTime = _parseTime(classSchedule.startTime);
    TimeOfDay endTime = _parseTime(classSchedule.endTime);
    final roomController = TextEditingController(text: classSchedule.room ?? '');
    String rescheduleScope = 'this_occurrence';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(
              'Reschedule Class',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classSchedule.course?.name ?? 'Class',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Scope of change:',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(
                    title: 'This occurrence only (${DateFormat('EEE, MMM d').format(targetDate)})',
                    isSelected: rescheduleScope == 'this_occurrence',
                    onTap: () => setState(() => rescheduleScope = 'this_occurrence'),
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(
                    title: 'Every ${_days[classSchedule.dayOfWeek - 1]}',
                    isSelected: rescheduleScope == 'every_weekday',
                    onTap: () => setState(() => rescheduleScope = 'every_weekday'),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Start Time',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(context: ctx, initialTime: startTime);
                                if (picked != null) setState(() => startTime = picked);
                              },
                              child: Text(
                                startTime.format(ctx),
                                style: AppTheme.monoTimeStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New End Time',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: () async {
                                final picked = await showTimePicker(context: ctx, initialTime: endTime);
                                if (picked != null) setState(() => endTime = picked);
                              },
                              child: Text(
                                endTime.format(ctx),
                                style: AppTheme.monoTimeStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: 'New Room / Location',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final formattedStart =
                      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                  final formattedEnd =
                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
                  final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

                  try {
                    final notifier = ref.read(timetableProvider.notifier);
                    if (rescheduleScope == 'this_occurrence') {
                      await notifier.addOverride(
                        classScheduleId: classSchedule.id,
                        overrideDate: dateStr,
                        type: 'rescheduled',
                        newStartTime: formattedStart,
                        newEndTime: formattedEnd,
                        newRoom: roomController.text.trim(),
                      );
                      if (ctx.mounted) {
                        SnackbarUtils.showSuccess(
                            ctx, 'Rescheduled for ${DateFormat('MMM d').format(targetDate)}');
                      }
                    } else {
                      await notifier.updateClass(classSchedule.copyWith(
                        startTime: formattedStart,
                        endTime: formattedEnd,
                        room: roomController.text.trim(),
                      ));
                      if (ctx.mounted) SnackbarUtils.showSuccess(ctx, 'Updated recurring schedule');
                    }
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  } catch (e) {
                    if (ctx.mounted) SnackbarUtils.showError(ctx, e.toString());
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    String cancelScope = 'this_occurrence';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(
              'Cancel / Delete Class',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How would you like to cancel "${classSchedule.course?.name ?? 'this class'}"?',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14),
                ),
                const SizedBox(height: 14),
                _buildOptionTile(
                  title: 'Cancel this occurrence only (${DateFormat('EEE, MMM d').format(targetDate)})',
                  isSelected: cancelScope == 'this_occurrence',
                  onTap: () => setState(() => cancelScope = 'this_occurrence'),
                ),
                const SizedBox(height: 8),
                _buildOptionTile(
                  title: 'Delete recurring class schedule completely',
                  isSelected: cancelScope == 'permanently_delete',
                  onTap: () => setState(() => cancelScope = 'permanently_delete'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Back'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () async {
                  final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
                  try {
                    final notifier = ref.read(timetableProvider.notifier);
                    if (cancelScope == 'this_occurrence') {
                      await notifier.addOverride(
                        classScheduleId: classSchedule.id,
                        overrideDate: dateStr,
                        type: 'cancelled',
                      );
                      if (ctx.mounted) {
                        SnackbarUtils.showInfo(
                            ctx, 'Class cancelled for ${DateFormat('MMM d').format(targetDate)}');
                      }
                    } else {
                      await notifier.deleteClass(classSchedule.id);
                      if (ctx.mounted) {
                        SnackbarUtils.showInfo(ctx, 'Recurring class schedule deleted');
                      }
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    if (ctx.mounted) SnackbarUtils.showError(ctx, e.toString());
                  }
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              classSchedule.course?.name ?? 'Class Options',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${classSchedule.startTime} - ${classSchedule.endTime}${classSchedule.room != null && classSchedule.room!.isNotEmpty ? ' • ${classSchedule.room}' : ''}',
              style: AppTheme.monoTimeStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined, color: AppColors.primary),
            title: Text('Reschedule Class', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            subtitle: Text('Change time, date, or room for single or recurring class',
                style: GoogleFonts.plusJakartaSans(fontSize: 12)),
            onTap: () {
              Navigator.of(context).pop();
              _showRescheduleDialog(context, ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text('Edit Recurring Details', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            subtitle: Text('Change course, day of week, or default time',
                style: GoogleFonts.plusJakartaSans(fontSize: 12)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddClassScreen(classSchedule: classSchedule),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
            title: Text('Cancel / Remove Class',
                style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontWeight: FontWeight.bold)),
            subtitle: Text('Cancel this occurrence or delete recurring schedule',
                style: GoogleFonts.plusJakartaSans(fontSize: 12)),
            onTap: () {
              Navigator.of(context).pop();
              _showCancelDialog(context, ref);
            },
          ),
        ],
      ),
    ),
    );
  }
}
