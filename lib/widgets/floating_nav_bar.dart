import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'ai_node_icon.dart';

class FloatingNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar> {
  double _assistantScale = 1.0;

  void _onAssistantTapDown(TapDownDetails details) {
    setState(() => _assistantScale = 0.92);
  }

  void _onAssistantTapUp(TapUpDetails details) {
    setState(() => _assistantScale = 1.0);
  }

  void _onAssistantTapCancel() {
    setState(() => _assistantScale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;

    final pillBg = isDark
        ? AppColors.darkSurface.withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.85);

    final pillBorder = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.6)
        : AppColors.lightBorder.withValues(alpha: 0.7);

    const double barHeight = 66.0;
    const double buttonSize = 54.0;

    return SizedBox(
      height: barHeight + 16, // Height including raised button top offset
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Frosted Glass Floating Pill Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: pillBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Slot 0: Home
                      Expanded(
                        child: _buildStandardTabItem(
                          context: context,
                          index: 0,
                          label: 'Home',
                          outlineIcon: Icons.home_outlined,
                          filledIcon: Icons.home_rounded,
                        ),
                      ),

                      // Slot 1: Timetable
                      Expanded(
                        child: _buildStandardTabItem(
                          context: context,
                          index: 1,
                          label: 'Timetable',
                          outlineIcon: Icons.calendar_today_outlined,
                          filledIcon: Icons.calendar_today_rounded,
                        ),
                      ),

                      // Slot 2: Assistant (Reserved Slot for Raised Button)
                      Expanded(
                        child: _buildAssistantLabelSlot(
                          context: context,
                        ),
                      ),

                      // Slot 3: Courses
                      Expanded(
                        child: _buildStandardTabItem(
                          context: context,
                          index: 3,
                          label: 'Courses',
                          outlineIcon: Icons.school_outlined,
                          filledIcon: Icons.school_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // PROMOTED RAISED ASSISTANT CENTER BUTTON (No glow, no halo, soft drop shadow only)
          Positioned(
            top: 0,
            child: GestureDetector(
              onTapDown: disableAnimations ? null : _onAssistantTapDown,
              onTapUp: disableAnimations ? null : _onAssistantTapUp,
              onTapCancel: disableAnimations ? null : _onAssistantTapCancel,
              onTap: () => widget.onTabSelected(2),
              child: AnimatedScale(
                scale: _assistantScale,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.aiAccent,
                    border: Border.all(
                      color: isDark ? AppColors.darkBackground : Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AiNodeIcon(
                      size: 24,
                      color: Colors.white,
                      animate: widget.selectedIndex == 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardTabItem({
    required BuildContext context,
    required int index,
    required String label,
    required IconData outlineIcon,
    required IconData filledIcon,
  }) {
    final isSelected = widget.selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: () => widget.onTabSelected(index),
      borderRadius: BorderRadius.circular(24),
      splashColor: AppColors.primary.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? filledIcon : outlineIcon,
            color: isSelected ? activeColor : inactiveColor,
            size: 22,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantLabelSlot({
    required BuildContext context,
  }) {
    final isSelected = widget.selectedIndex == 2;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = AppColors.aiAccent;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: () => widget.onTabSelected(2),
      borderRadius: BorderRadius.circular(24),
      splashColor: AppColors.aiAccent.withValues(alpha: 0.1),
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Assistant',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
