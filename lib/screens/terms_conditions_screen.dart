import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../utils/constants.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
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
                            'DRAFT FOR LEGAL REVIEW — This document is a pre-release draft based on current app technical features and is subject to formal legal review before final release.',
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
                    'Terms & Conditions',
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
                    title: '1. Agreement to Terms',
                    content:
                        'By creating an account or accessing Sentry Academic Assistant ("the App"), you agree to be bound by these Terms & Conditions. If you do not agree, do not use the application.',
                  ),
                  _buildSection(
                    context,
                    title: '2. User Accounts & Verification',
                    content:
                        'You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account. You must provide a valid email address during registration.',
                  ),
                  _buildSection(
                    context,
                    title: '3. Academic Content & AI Services',
                    content:
                        'The App provides AI-assisted schedule extraction from images and prompts. While we strive for accuracy, AI outputs are suggestions for convenience. Users remain solely responsible for verifying class times, room numbers, and academic deadline accuracy with their institution.',
                  ),
                  _buildSection(
                    context,
                    title: '4. Acceptable Use',
                    content:
                        'You agree not to upload malicious files, attempt unauthorized access to servers, or misuse the AI processing endpoints beyond intended personal academic management.',
                  ),
                  _buildSection(
                    context,
                    title: '5. Account Termination & Data Erasure',
                    content:
                        'You may terminate your account at any time via the in-app Profile Settings > Delete Account feature. We reserve the right to suspend accounts that violate acceptable use guidelines.',
                  ),
                  _buildSection(
                    context,
                    title: '6. Contact & Support',
                    content:
                        'For questions or support regarding these Terms, please contact support@sentryapp.com.',
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
