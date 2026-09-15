import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/navigation_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/ai_node_icon.dart';
import 'cookies_policy_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _readAllEmails = false;
  List<Map<String, dynamic>> _emailFilters = [];
  bool _isLoadingFilters = true;
  List<Map<String, dynamic>> _linkedAccounts = [];
  bool _isLoadingAccounts = true;

  @override
  void initState() {
    super.initState();
    _loadProfileSettings();
    _loadEmailFilters();
    _loadLinkedAccounts();
  }

  Future<void> _loadProfileSettings() async {
    try {
      final profile = await _authService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _readAllEmails = profile['read_all_emails'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEmailFilters() async {
    try {
      final filters = await _authService.getEmailFilters();
      if (mounted) {
        setState(() {
          _emailFilters = filters;
          _isLoadingFilters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFilters = false);
    }
  }

  Future<void> _loadLinkedAccounts() async {
    try {
      final accounts = await _authService.getLinkedGmailAccounts();
      if (mounted) {
        setState(() {
          _linkedAccounts = accounts;
          _isLoadingAccounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAccounts = false);
    }
  }

  Future<void> _linkAdditionalAccount() async {
    try {
      await _authService.linkAdditionalGoogleAccount();
      await _authService.saveGmailRefreshToken();
      await _loadLinkedAccounts();
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Institute Gmail account linked successfully!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to link account: $e');
      }
    }
  }

  Future<void> _removeLinkedAccount(String accountId) async {
    try {
      await _authService.removeLinkedGmailAccount(accountId);
      await _loadLinkedAccounts();
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Gmail account unlinked');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to unlink: $e');
      }
    }
  }

  Future<void> _updateReadAllEmails(bool value) async {
    setState(() => _readAllEmails = value);
    try {
      await _authService.updateReadAllEmails(value);
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Email scanning preference updated!');
      }
    } catch (e) {
      setState(() => _readAllEmails = !value);
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to update preference: $e');
      }
    }
  }

  void _showAddFilterDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Add Trusted Sender',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'e.g., academics@iitmandi.ac.in',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an email address';
                  }
                  if (!val.contains('@') || !val.contains('.')) {
                    return 'Please enter a valid email address';
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
                            await _authService.addEmailFilter(emailController.text.trim());
                            await _loadEmailFilters();
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) SnackbarUtils.showSuccess(context, 'Trusted sender added successfully!');
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
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteFilter(String filterId) async {
    try {
      await _authService.deleteEmailFilter(filterId);
      await _loadEmailFilters();
      if (mounted) SnackbarUtils.showSuccess(context, 'Trusted sender removed');
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, 'Failed to remove: $e');
    }
  }

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
                          tooltip: obscure ? 'Show password' : 'Hide password',
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
          'Are you sure you want to log out of Sentry?',
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

            // Email Scanning & Privacy
            Text(
              'Email Scanning & Privacy',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildSwitchTile(
              context: context,
              icon: Icons.mark_email_read_outlined,
              iconColor: AppColors.primary,
              title: 'Read All Inbox Emails',
              subtitle: _readAllEmails
                  ? 'Scanning all inbox messages for class cancellations/updates'
                  : 'Scanning only specified trusted sender filters (Strict Privacy)',
              value: _readAllEmails,
              onChanged: _updateReadAllEmails,
            ),

            if (!_readAllEmails) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trusted Senders List',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddFilterDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Sender'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sentry will only read emails from these specific senders.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingFilters)
                      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                    else if (_emailFilters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No custom senders added yet. Default fallback: academics@iitmandi.ac.in',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _emailFilters.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final filter = _emailFilters[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.alternate_email, size: 18, color: AppColors.primary),
                            title: Text(
                              filter['sender_email'] ?? '',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                              onPressed: () => _deleteFilter(filter['id']),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Linked Gmail Inboxes (Multi-Account Support)
            Text(
              'Linked Gmail Inboxes',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Link both your personal and institute Google accounts to scan both inboxes.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Connected Inboxes',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _linkAdditionalAccount,
                          icon: const Icon(Icons.add_link, size: 16),
                          label: const Text('Link Institute ID'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingAccounts)
                      const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                    else if (_linkedAccounts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No additional inboxes linked yet. (Primary login account is active)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _linkedAccounts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final acc = _linkedAccounts[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.mark_email_unread_outlined, size: 18, color: AppColors.primary),
                            title: Text(
                              acc['google_email'] ?? 'Google Account',
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.link_off, size: 18, color: AppColors.error),
                              onPressed: () => _removeLinkedAccount(acc['id']),
                              tooltip: 'Unlink account',
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Appearance & Theme
            Text(
              'Appearance & Theme',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildThemeSelectionCard(context),

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

            const SizedBox(height: 24),

            // Legal & Compliance Section
            Text(
              'Legal & Compliance',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            _buildTile(
              context: context,
              icon: Icons.privacy_tip_outlined,
              iconColor: AppColors.primary,
              title: 'Privacy Policy',
              subtitle: 'How we collect, use, and protect your data',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
            const SizedBox(height: 8),

            _buildTile(
              context: context,
              icon: Icons.description_outlined,
              iconColor: AppColors.secondary,
              title: 'Terms & Conditions',
              subtitle: 'User agreement, AI usage, and policies',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
                );
              },
            ),
            const SizedBox(height: 8),

            _buildTile(
              context: context,
              icon: Icons.cookie_outlined,
              iconColor: AppColors.aiAccent,
              title: 'Cookies & Storage Policy',
              subtitle: 'Session tokens and local preferences',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CookiesPolicyScreen()),
                );
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
        ),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSelectionCard(BuildContext context) {
    final currentTheme = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final options = [
      (ThemeMode.light, 'Light Mode', 'Default theme', Icons.wb_sunny_outlined),
      (ThemeMode.dark, 'Dark Mode', 'Low light theme', Icons.dark_mode_outlined),
      (ThemeMode.system, 'System Mode', 'Follows OS theme', Icons.brightness_auto_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: options.map((option) {
          final mode = option.$1;
          final label = option.$2;
          final subtitle = option.$3;
          final icon = option.$4;
          final isSelected = currentTheme == mode;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(mode);
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 22,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.85)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

