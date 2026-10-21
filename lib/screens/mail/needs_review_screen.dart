import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/class_update.dart';
import '../../providers/mail_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_utils.dart';

class NeedsReviewScreen extends ConsumerStatefulWidget {
  const NeedsReviewScreen({super.key});

  @override
  ConsumerState<NeedsReviewScreen> createState() => _NeedsReviewScreenState();
}

class _NeedsReviewScreenState extends ConsumerState<NeedsReviewScreen> {
  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('EEE, d MMM · h:mm a').format(dt);
  }

  Future<void> _confirmItem(ClassUpdate item) async {
    await ref.read(mailRepositoryProvider).setStatus(item.id, 'confirmed');
    if (mounted) {
      SnackbarUtils.showSuccess(context, 'Confirmed: ${item.title}');
    }
  }

  Future<void> _dismissItem(ClassUpdate item) async {
    await ref.read(mailRepositoryProvider).setStatus(item.id, 'dismissed');
    if (mounted) {
      SnackbarUtils.showInfo(context, 'Dismissed update');
    }
  }

  Future<void> _showEditDialog(ClassUpdate item) async {
    final titleController = TextEditingController(text: item.title);
    final courseController = TextEditingController(text: item.course ?? '');
    String currentType = item.type;

    final typeOptions = [
      'cancelled',
      'postponed',
      'rescheduled',
      'room_change',
      'quiz',
      'exam',
      'assignment',
      'info',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit & Confirm Update',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: courseController,
                  decoration: InputDecoration(
                    labelText: 'Course Name / Code',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Category Type',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: typeOptions.map((t) {
                    final selected = currentType == t;
                    return ChoiceChip(
                      label: Text(t.toUpperCase()),
                      selected: selected,
                      onSelected: (val) {
                        if (val) setDialogState(() => currentType = t);
                      },
                    );
                  }).toList(),
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
                final newTitle = titleController.text.trim();
                final newCourse = courseController.text.trim();

                await ref.read(mailRepositoryProvider).updateAndConfirm(
                  item.id,
                  title: newTitle.isNotEmpty ? newTitle : null,
                  course: newCourse.isNotEmpty ? newCourse : null,
                  type: currentType,
                );

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  SnackbarUtils.showSuccess(context, 'Update confirmed!');
                }
              },
              child: const Text('Confirm & Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(needsReviewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Needs Review',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
      ),
      body: pendingAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.sentryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 48,
                        color: AppColors.sentryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All Caught Up!',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No pending email detections require manual review right now.',
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
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                          child: Text(
                            item.typeLabel,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: item.typeColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Confidence ${(item.confidence * 100).toInt()}%',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.course != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Course: ${item.course}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    if (item.startsAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Time: ${_formatDateTime(item.startsAt)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (item.rawSnippet != null && item.rawSnippet!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.rawSnippet!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => _dismissItem(item),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text('Not Class Email'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _showEditDialog(item),
                          child: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _confirmItem(item),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.sentryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
