import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
                            'DRAFT FOR LEGAL REVIEW — This document is a pre-release draft based on current app technical architecture and is subject to formal legal review before final release.',
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
                    'Privacy Policy',
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
                    title: '1. Overview & Entity',
                    content:
                        'Sentry Academic Assistant ("we", "us", or "our") is committed to protecting your privacy. This Privacy Policy explains how personal data is collected, stored, and processed when you use our mobile and web applications.',
                  ),
                  _buildSection(
                    context,
                    title: '2. Information We Collect',
                    content:
                        'We collect information necessary to provide academic scheduling, task management, and AI assistance:\n\n'
                        '• Account Data: Full name, email address, password hash (processed securely via Supabase Auth), and user profile metadata.\n'
                        '• Academic Data: Course names, codes, instructor details, class times, room locations, schedule overrides, and task items.\n'
                        '• AI Assistant Inputs: Text prompts, chat messages, and uploaded timetable image files sent to the AI assistant for schedule parsing.\n'
                        '• Device & Preferences: Theme settings (dark/light) and local notification reminders.',
                  ),
                  _buildSection(
                    context,
                    title: '3. How We Use Your Information',
                    content:
                        '• Operating and personalizing your academic schedule and tasks.\n'
                        '• Generating automated timetable schedules from user input or uploaded images using AI processing.\n'
                        '• Sending local notification alerts for upcoming classes and assignment deadlines.\n'
                        '• Securing user accounts and maintaining application integrity.',
                  ),
                  _buildSection(
                    context,
                    title: '4. Third-Party Service Providers',
                    content:
                        'We use reputable third-party infrastructure providers:\n\n'
                        '• Supabase Inc.: Database storage, account authentication, and edge function execution.\n'
                        '• OpenRouter / AI Providers: Secure processing of timetable image extraction and chat prompts.',
                  ),
                  _buildSection(
                    context,
                    title: '5. Data Retention & User Control',
                    content:
                        'Your data is retained for as long as your account is active. You may clear your AI chat history at any time in the app settings or delete your account permanently via Profile Settings > Delete Account, which purges all stored records.',
                  ),
                  _buildSection(
                    context,
                    title: '6. Contact Us',
                    content:
                        'For questions or privacy concerns regarding this policy, please contact us at support@sentryapp.com.',
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
