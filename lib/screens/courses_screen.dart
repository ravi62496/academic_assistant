import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/course.dart';
import '../providers/course_providers.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_utils.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  void _showCourseDialog(BuildContext context, WidgetRef ref, [Course? course]) {
    final isEditing = course != null;
    final nameController = TextEditingController(text: course?.name ?? '');
    final codeController = TextEditingController(text: course?.code ?? '');
    final profController = TextEditingController(text: course?.professor ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEditing ? 'Edit Course' : 'Add New Course',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Course Name *',
                    hintText: 'e.g. Computer Networks',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Course name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code',
                    hintText: 'e.g. CS 301',
                    prefixIcon: Icon(Icons.label_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: profController,
                  decoration: const InputDecoration(
                    labelText: 'Professor / Instructor',
                    hintText: 'e.g. Dr. Alan Turing',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                try {
                  final notifier = ref.read(coursesProvider.notifier);
                  if (isEditing) {
                    await notifier.updateCourse(
                      course.copyWith(
                        name: nameController.text.trim(),
                        code: codeController.text.trim(),
                        professor: profController.text.trim(),
                      ),
                    );
                    if (ctx.mounted) SnackbarUtils.showSuccess(ctx, 'Course updated');
                  } else {
                    await notifier.addCourse(
                      name: nameController.text.trim(),
                      code: codeController.text.trim(),
                      professor: profController.text.trim(),
                    );
                    if (ctx.mounted) SnackbarUtils.showSuccess(ctx, 'Course added');
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) SnackbarUtils.showError(ctx, e.toString());
                }
              }
            },
            child: Text(isEditing ? 'Save Changes' : 'Add Course'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Course course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Course',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${course.name}"? This will also remove any associated class schedules.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              try {
                await ref.read(coursesProvider.notifier).deleteCourse(course.id);
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  SnackbarUtils.showInfo(ctx, 'Course deleted');
                }
              } catch (e) {
                if (ctx.mounted) SnackbarUtils.showError(ctx, e.toString());
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Courses',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
      ),
      body: coursesAsync.when(
        data: (courses) {
          if (courses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        size: 54,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Courses Added Yet',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your subjects to organize timetables and track class schedules.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(200, 48),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add First Course'),
                      onPressed: () => _showCourseDialog(context, ref),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(coursesProvider.notifier).loadCourses(),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              itemCount: courses.length,
              separatorBuilder: (ctx, index) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final course = courses[index];
                final courseColor = AppColors.getCourseColor(course.id);

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          // Distinct Per-Course Color Tag Bar
                          Container(
                            width: 6,
                            color: courseColor,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Course Avatar Node
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: courseColor.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            course.name.isNotEmpty
                                                ? course.name[0].toUpperCase()
                                                : 'C',
                                            style: GoogleFonts.spaceGrotesk(
                                              color: courseColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          course.name,
                                          style: GoogleFonts.spaceGrotesk(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),

                                      // Actions
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 19),
                                        tooltip: 'Edit Course',
                                        onPressed: () => _showCourseDialog(context, ref, course),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 19, color: AppColors.error),
                                        tooltip: 'Delete Course',
                                        onPressed: () => _confirmDelete(context, ref, course),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Details Row (Code Badge & Instructor)
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (course.code != null && course.code!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: courseColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            course.code!,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: courseColor,
                                            ),
                                          ),
                                        ),
                                      if (course.professor != null &&
                                          course.professor!.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              course.professor!,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading courses: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(coursesProvider.notifier).loadCourses(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'courses_fab',
        backgroundColor: AppColors.primary,
        onPressed: () => _showCourseDialog(context, ref),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Course',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
