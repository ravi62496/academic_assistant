import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/navigation_providers.dart';
import '../providers/notification_providers.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/ai_node_icon.dart';
import 'login_screen.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final AuthService _authService = AuthService();

  void _showEditNameDialog(String currentName) {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Edit Name',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  if (val.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() ?? false) {
                          setModalState(() => isSaving = true);
                          try {
                            await _authService.updateProfile(
                              fullName: nameController.text.trim(),
                            );
                            if (mounted) {
                              setState(() {}); // Refresh UI name
                              SnackbarUtils.showSuccess(context, 'Name updated successfully!');
                            }
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              SnackbarUtils.showError(ctx, e.toString());
                            }
                          } finally {
                            if (ctx.mounted) setModalState(() => isSaving = false);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Change Password',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setModalState(() => obscure = !obscure),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Password is required';
                        if (val.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: confirmController,
                      obscureText: obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_clock_outlined),
                      ),
                      validator: (val) {
                        if (val != passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() ?? false) {
                          setModalState(() => isSaving = true);
                          try {
                            await _authService.updatePassword(passwordController.text.trim());
                            if (mounted) {
                              SnackbarUtils.showSuccess(context, 'Password updated successfully!');
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          } catch (e) {
                            if (ctx.mounted) SnackbarUtils.showError(ctx, e.toString());
                          } finally {
                            if (ctx.mounted) setModalState(() => isSaving = false);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of Academic Assistant?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          SnackbarUtils.showInfo(context, 'You have been logged out.');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _authService.displayName;
    final email = _authService.currentUser?.email ?? 'Student Account';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Student Profile',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, letterSpacing: -0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Avatar & Name Card Header (With Edit Action)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: GoogleFonts.spaceGrotesk(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 30,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _showEditNameDialog(name),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name.isNotEmpty ? name : 'Student',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                        tooltip: 'Edit Name',
                        onPressed: () => _showEditNameDialog(name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Name'),
                    onPressed: () => _showEditNameDialog(name),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Account Security / Preferences
            Text(
              'Account Security',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildTile(
              context: context,
              icon: Icons.lock_reset_outlined,
              iconColor: AppColors.primary,
              title: 'Change Password',
              subtitle: 'Update your account login password',
              onTap: _showChangePasswordDialog,
            ),

            const SizedBox(height: 24),

            // Notifications & Reminders
            Text(
              'Notifications & Alarms',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildSwitchTile(
              context: context,
              icon: Icons.alarm_on_outlined,
              iconColor: AppColors.primary,
              title: '10-Min Pre-Class Alert',
              subtitle: 'Alert 10 minutes before every scheduled class',
              value: ref.watch(notificationSettingsProvider).classAlertsEnabled,
              onChanged: (val) {
                ref.read(notificationSettingsProvider.notifier).toggleClassAlerts(val);
              },
            ),
            const SizedBox(height: 8),

            _buildSwitchTile(
              context: context,
              icon: Icons.wb_sunny_outlined,
              iconColor: Colors.orange,
              title: 'Daily Morning Briefing (7:30 AM)',
              subtitle: 'Summary of today\'s scheduled classes & tasks',
              value: ref.watch(notificationSettingsProvider).morningBriefingEnabled,
              onChanged: (val) {
                ref.read(notificationSettingsProvider.notifier).toggleMorningBriefing(val);
              },
            ),
            const SizedBox(height: 8),

            _buildSwitchTile(
              context: context,
              icon: Icons.nights_stay_outlined,
              iconColor: Colors.indigoAccent,
              title: 'Nightly Schedule Preview (11:30 PM)',
              subtitle: 'Preview of tomorrow\'s timetable and tasks',
              value: ref.watch(notificationSettingsProvider).nightlyPreviewEnabled,
              onChanged: (val) {
                ref.read(notificationSettingsProvider.notifier).toggleNightlyPreview(val);
              },
            ),
            const SizedBox(height: 8),

            _buildTile(
              context: context,
              icon: Icons.notifications_active_outlined,
              iconColor: AppColors.secondary,
              title: 'Test Notification System',
              subtitle: 'Send an immediate test notification now',
              onTap: () async {
                await NotificationService().sendTestNotification();
                if (context.mounted) {
                  SnackbarUtils.showSuccess(context, 'Test notification sent!');
                }
              },
            ),


            const SizedBox(height: 24),

            // Quick Navigation Shortcuts
            Text(
              'Quick Navigation',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildTile(
              context: context,
              icon: Icons.calendar_month_outlined,
              iconColor: AppColors.primary,
              title: 'Weekly Timetable',
              subtitle: 'View and manage recurring weekly classes',
              onTap: () {
                ref.read(activeTabProvider.notifier).selectTab(1); // Timetable tab
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),

            _buildTile(
              context: context,
              iconWidget: const AiNodeIcon(size: 20, color: AppColors.aiAccent),
              title: 'AI Assistant',
              subtitle: 'Smart schedule changes and timetable photo import',
              onTap: () {
                ref.read(activeTabProvider.notifier).selectTab(2); // Assistant tab
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),

            _buildTile(
              context: context,
              icon: Icons.school_outlined,
              iconColor: AppColors.secondary,
              title: 'My Courses',
              subtitle: 'Manage subjects, professors, and course codes',
              onTap: () {
                ref.read(activeTabProvider.notifier).selectTab(3); // Courses tab
                Navigator.of(context).pop();
              },
            ),

            const SizedBox(height: 32),

            // Log Out Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(
                  'Log Out of Account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _handleLogout,
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    IconData? icon,
    Widget? iconWidget,
    Color iconColor = AppColors.primary,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: iconWidget ?? Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: SwitchListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        value: value,
        onChanged: onChanged,
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

