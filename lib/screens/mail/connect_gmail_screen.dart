import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/mail_providers.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_utils.dart';
import 'choose_sources_screen.dart';

class ConnectGmailScreen extends ConsumerStatefulWidget {
  const ConnectGmailScreen({super.key});

  @override
  ConsumerState<ConnectGmailScreen> createState() => _ConnectGmailScreenState();
}

class _ConnectGmailScreenState extends ConsumerState<ConnectGmailScreen> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  Future<void> _handleConnect() async {
    setState(() => _isLoading = true);

    try {
      // 1. Trigger OAuth with gmail.readonly scope & offline access
      await _authService.linkAdditionalGoogleAccount();

      // Give brief moment for deep-link session update
      await Future.delayed(const Duration(milliseconds: 800));

      final session = Supabase.instance.client.auth.currentSession;
      final refreshToken = session?.providerRefreshToken;
      final accessToken = session?.providerToken;

      // 2. Invoke connect-gmail edge function to register credentials securely
      final res = await Supabase.instance.client.functions.invoke(
        'connect-gmail',
        body: {
          if (refreshToken != null) 'refreshToken': refreshToken,
          if (accessToken != null) 'accessToken': accessToken,
        },
      );

      if (res.status == 200 || res.status == 201) {
        ref.invalidate(isGmailConnectedProvider);
        ref.invalidate(mailSettingsProvider);

        if (mounted) {
          SnackbarUtils.showSuccess(context, 'Gmail connected securely!');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const ChooseSourcesScreen(isInitialSetup: true),
            ),
          );
        }
      } else {
        final err = res.data?['error'] ?? 'Could not initialize Gmail sync.';
        if (mounted) {
          SnackbarUtils.showError(context, err);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Connection cancelled or failed: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Connect Email',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Hero Icon / Badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Class Email Intelligence',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Never miss a class cancellation, rescheduled lecture, room change, or quiz deadline from your professors.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Privacy & Security Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.sentryGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Strict Privacy Principles',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.sentryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPrivacyItem(
                      icon: Icons.visibility_outlined,
                      title: 'Read-Only Access',
                      description: 'Sentry can only inspect incoming emails. It can NEVER send, delete, or edit any of your emails.',
                    ),
                    const Divider(height: 24),
                    _buildPrivacyItem(
                      icon: Icons.no_encryption_gmailerrorred_outlined,
                      title: 'No Email Bodies Stored',
                      description: 'We only extract class title, time, room, and status. Full email bodies are never stored in our database.',
                    ),
                    const Divider(height: 24),
                    _buildPrivacyItem(
                      icon: Icons.vpn_key_outlined,
                      title: 'Server-Side Vault',
                      description: 'OAuth tokens are kept strictly server-side in encrypted storage. Nothing sensitive is saved on device.',
                    ),
                    const Divider(height: 24),
                    _buildPrivacyItem(
                      icon: Icons.delete_forever_outlined,
                      title: 'One-Tap Purge',
                      description: 'You can disconnect and permanently wipe all extracted notices and tasks whenever you wish.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Connect Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open_rounded, size: 20),
                  label: Text(
                    _isLoading ? 'Connecting...' : 'Connect with Google',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Maybe Later',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

