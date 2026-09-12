import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/ai_node_icon.dart';
import 'ai_assistant_screen.dart';
import 'courses_screen.dart';
import 'home_screen.dart';
import 'weekly_timetable_screen.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    WeeklyTimetableScreen(),
    AiAssistantScreen(),
    CoursesScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeIndex = ref.watch(activeTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: activeIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: activeIndex,
          onDestinationSelected: (index) {
            ref.read(activeTabProvider.notifier).selectTab(index);
          },
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          indicatorColor: activeIndex == 2
              ? AppColors.aiAccent.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.18),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
              label: 'Timetable',
            ),
            NavigationDestination(
              icon: AiNodeIcon(size: 22, color: AppColors.aiAccent, animate: false),
              selectedIcon: AiNodeIcon(size: 22, color: AppColors.aiAccent, animate: true),
              label: 'Assistant',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded, color: AppColors.primary),
              label: 'Courses',
            ),
          ],
        ),
      ),
    );
  }
}
