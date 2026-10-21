import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/class_update.dart';
import '../../providers/mail_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_utils.dart';
import 'choose_sources_screen.dart';

class ClassNoticesScreen extends ConsumerStatefulWidget {
  const ClassNoticesScreen({super.key});

  @override
  ConsumerState<ClassNoticesScreen> createState() => _ClassNoticesScreenState();
}

class _ClassNoticesScreenState extends ConsumerState<ClassNoticesScreen> {
  String _selectedFilter = 'all'; // 'all', 'cancelled', 'postponed', 'room_change', 'tasks'

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('EEE, d MMM · h:mm a').format(dt);
  }

  void _showNoticeDetail(ClassUpdate update) {
    // Mark as read
    if (!update.isRead) {
      ref.read(mailRepositoryProvider).markRead(update.id);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: update.typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(update.typeIcon, size: 14, color: update.typeColor),
                      const SizedBox(width: 6),
                      Text(
                        update.typeLabel,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: update.typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDateTime(update.createdAt),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              update.title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (update.course != null) ...[
              const SizedBox(height: 6),
              Text(
                'Course: ${update.course}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
            const Divider(height: 24),

            if (update.startsAt != null)
              _buildDetailRow(
                icon: Icons.calendar_today_outlined,
                label: update.newStartsAt != null ? 'Original Schedule' : 'Scheduled Time',
                value: _formatDateTime(update.startsAt),
              ),

            if (update.newStartsAt != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.update_outlined,
                label: 'Rescheduled To',
                value: _formatDateTime(update.newStartsAt),
                valueColor: AppColors.sentryGreen,
              ),
            ],

            if (update.room != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.meeting_room_outlined,
                label: 'Room / Venue',
                value: update.room!,
                valueColor: AppColors.primary,
              ),
            ],

            if (update.sender != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                icon: Icons.person_outline,
                label: 'Sender',
                value: update.sender!,
              ),
            ],

            if (update.rawSnippet != null && update.rawSnippet!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Email Preview',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  update.rawSnippet!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Dismiss Notice'),
                    onPressed: () async {
                      await ref.read(mailRepositoryProvider).setStatus(update.id, 'dismissed');
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(classNoticesProvider);
    final tasksAsync = ref.watch(classTasksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Class Intelligence Feed',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            tooltip: 'Mark All Read',
            onPressed: () async {
              await ref.read(mailRepositoryProvider).markAllNoticesRead();
              if (context.mounted) {
                SnackbarUtils.showSuccess(context, 'All marked as read');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Sender Sources',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChooseSourcesScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final count = await ref.read(mailRepositoryProvider).triggerSync();
          if (context.mounted) {
            SnackbarUtils.showSuccess(
              context,
              count > 0 ? 'Sync complete: $count new update(s)' : 'Already up to date',
            );
          }
        },
        child: Column(
          children: [
            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildChip('all', 'All Updates'),
                  const SizedBox(width: 8),
                  _buildChip('cancelled', 'Cancelled'),
                  const SizedBox(width: 8),
                  _buildChip('postponed', 'Postponed / Rescheduled'),
                  const SizedBox(width: 8),
                  _buildChip('room_change', 'Room Changes'),
                  const SizedBox(width: 8),
                  _buildChip('tasks', 'Academic Deadlines'),
                ],
              ),
            ),

            Expanded(
              child: noticesAsync.when(
                data: (notices) {
                  return tasksAsync.when(
                    data: (tasks) {
                      // Merge items according to current filter
                      List<ClassUpdate> items = [];
                      if (_selectedFilter == 'all') {
                        items = [...notices, ...tasks];
                      } else if (_selectedFilter == 'tasks') {
                        items = tasks;
                      } else if (_selectedFilter == 'cancelled') {
                        items = notices.where((n) => n.type == 'cancelled').toList();
                      } else if (_selectedFilter == 'postponed') {
                        items = notices.where((n) => n.type == 'postponed' || n.type == 'rescheduled').toList();
                      } else if (_selectedFilter == 'room_change') {
                        items = notices.where((n) => n.type == 'room_change').toList();
                      }

                      if (items.isEmpty) {
                        return Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No Class Updates Yet',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sentry monitors incoming emails from your professors. Pull down to scan now or verify your sender sources.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          return _buildNoticeCard(item, isDark);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedFilter = key);
      },
    );
  }

  Widget _buildNoticeCard(ClassUpdate item, bool isDark) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(mailRepositoryProvider).setStatus(item.id, 'dismissed');
      },
      child: InkWell(
        onTap: () => _showNoticeDetail(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !item.isRead
                  ? AppColors.primary
                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
              width: !item.isRead ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.typeIcon, size: 12, color: item.typeColor),
                        const SizedBox(width: 4),
                        Text(
                          item.typeLabel,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: item.typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.course != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        item.course!,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!item.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                item.title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (item.newStartsAt != null || item.startsAt != null || item.room != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      item.newStartsAt != null
                          ? 'Moved to ${_formatDateTime(item.newStartsAt)}'
                          : _formatDateTime(item.startsAt),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.room != null) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.meeting_room_outlined, size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        item.room!,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

