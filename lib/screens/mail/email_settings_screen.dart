import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/mail_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_utils.dart';
import 'choose_sources_screen.dart';
import 'connect_gmail_screen.dart';
import 'needs_review_screen.dart';

class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends ConsumerState<EmailSettingsScreen> {
  bool _isSyncing = false;
  bool _isPurging = false;

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    try {
      final processed = await ref.read(mailRepositoryProvider).triggerSync();
      ref.invalidate(mailSettingsProvider);
      ref.invalidate(classTasksProvider);
      ref.invalidate(classNoticesProvider);
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          processed > 0 ? 'Sync complete: $processed new update(s)!' : 'Inbox synced. No new class updates.',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Sync failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _showDisconnectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'Disconnect & Purge',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This will revoke Google permissions, disconnect Gmail, and permanently delete all your extracted class updates, notices, and sender configurations from Sentry.',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect & Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isPurging = true);
      try {
        await ref.read(mailRepositoryProvider).disconnectAndPurgeData();
        ref.invalidate(isGmailConnectedProvider);
        ref.invalidate(mailSettingsProvider);
        ref.invalidate(classTasksProvider);
        ref.invalidate(classNoticesProvider);
        ref.invalidate(emailSourcesProvider);

        if (mounted) {
          SnackbarUtils.showSuccess(context, 'All email data purged successfully.');
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Purge failed: $e');
        }
      } finally {
        if (mounted) setState(() => _isPurging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(mailSettingsProvider);
    final sourcesAsync = ref.watch(emailSourcesProvider);
    final pendingCount = ref.watch(pendingReviewCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Email Intelligence Settings',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (settings == null) {
            // Not connected yet
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                        Icons.mark_email_unread_outlined,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Gmail Not Connected',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect your university Gmail account to have Sentry automatically detect schedule changes, cancellations, and deadlines.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ConnectGmailScreen()),
                        );
                      },
                      icon: const Icon(Icons.link),
                      label: Text(
                        'Connect Gmail',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final sourcesCount = sourcesAsync.maybeWhen(
            data: (srcs) => srcs.length,
            orElse: () => 0,
          );

          final lastSyncedStr = settings.lastSyncedAt != null
              ? DateFormat('d MMM, h:mm a').format(settings.lastSyncedAt!.toLocal())
              : 'Never';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: settings.syncEnabled
                                  ? AppColors.sentryGreen.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              settings.syncEnabled ? Icons.sync : Icons.sync_disabled,
                              color: settings.syncEnabled ? AppColors.sentryGreen : Colors.orange,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settings.syncEnabled ? 'Sync Active' : 'Sync Paused',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Last synced: $lastSyncedStr',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isSyncing ? null : _manualSync,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            tooltip: 'Sync Now',
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Background Mail Sync',
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
                          ),
                          Switch(
                            value: settings.syncEnabled,
                            onChanged: (val) async {
                              await ref.read(mailRepositoryProvider).toggleSyncEnabled(val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Sources & Privacy Mode Card
                Text(
                  'Sender Privacy & Filters',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                        ),
                        title: Text(
                          'Sender Mode',
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          settings.mode == 'selected'
                              ? 'Selected Senders Only ($sourcesCount configured)'
                              : 'All Senders (Full Inbox Filter)',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ChooseSourcesScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Needs Review Card
                Text(
                  'Review Queue',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: pendingCount > 0
                            ? Colors.amber.withValues(alpha: 0.15)
                            : AppColors.sentryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        pendingCount > 0 ? Icons.help_outline : Icons.check_circle_outline,
                        color: pendingCount > 0 ? Colors.amber.shade800 : AppColors.sentryGreen,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Items Needing Review',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text(
                      pendingCount > 0
                          ? '$pendingCount item(s) awaiting your confirmation'
                          : 'No pending items',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12),
                    ),
                    trailing: pendingCount > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NeedsReviewScreen()),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 36),

                // Danger Zone: Disconnect & Purge
                Text(
                  'Data Privacy & Disconnect',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revoke Access & Delete Data',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Completely disconnects Gmail, revokes Google OAuth tokens, and purges all extracted class updates and sender rules.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isPurging ? null : _showDisconnectDialog,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isPurging
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                                )
                              : const Icon(Icons.delete_forever_outlined, size: 18),
                          label: Text(
                            _isPurging ? 'Purging Data...' : 'Disconnect & Delete All Mail Data',
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

