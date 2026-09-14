import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

class CookiesPolicyScreen extends StatelessWidget {
  const CookiesPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cookies Policy'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppConstants.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Draft Warning Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning, width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.gavel_rounded, color: AppColors.warning, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'DRAFT FOR LEGAL REVIEW — This document reflects actual session storage and local data preferences used in the application.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Cookies & Local Storage Policy',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Last updated: September 14, 2026',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    context,
                    title: '1. How We Use Cookies & Local Storage',
                    content:
                        'Sentry Academic Assistant uses essential cookies and local storage tokens strictly required for session security, authentication, and user preference persistence.',
                  ),
                  _buildSection(
                    context,
                    title: '2. Exact Storage Tokens Set',
                    content:
                        'The app sets and reads the following essential storage items:\n\n'
                        '• Supabase Auth JWT Session Tokens (`sb-access-token`, `sb-refresh-token`): Essential security tokens that maintain your secure sign-in state across app launches.\n'
                        '• User Theme Preference (`theme_mode`): Local preference key storing your selected dark or light mode preference.\n'
                        '• Cookie Consent Banner State (`cookie_consent_accepted`): Local preference flag storing your cookie/tracking consent choice.',
                  ),
                  _buildSection(
                    context,
                    title: '3. Third-Party Advertising & Analytics Cookies',
                    content:
                        'We do NOT use third-party advertising cookies, cross-site tracking pixels, or monetized data collection scripts.',
                  ),
                  _buildSection(
                    context,
                    title: '4. Managing Your Preferences',
                    content:
                        'You can adjust your cookie consent banner preferences or clear local data anytime via the Profile Settings menu in the application.',
                  ),
                  _buildSection(
                    context,
                    title: '5. Contact Information',
                    content:
                        'For questions regarding cookie management, please email support@sentryapp.com.',
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required String content}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              height: 1.55,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
