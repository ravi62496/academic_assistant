import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/email_source.dart';
import '../../providers/mail_providers.dart';
import '../../theme/app_colors.dart';
import '../../utils/snackbar_utils.dart';

class ChooseSourcesScreen extends ConsumerStatefulWidget {
  final bool isInitialSetup;

  const ChooseSourcesScreen({
    super.key,
    this.isInitialSetup = false,
  });

  @override
  ConsumerState<ChooseSourcesScreen> createState() => _ChooseSourcesScreenState();
}

class _ChooseSourcesScreenState extends ConsumerState<ChooseSourcesScreen> {
  String _mode = 'selected'; // 'selected' or 'all'
  bool _isLoadingDiscovered = false;
  bool _isSaving = false;

  // List of discovered senders from last 30 days
  List<Map<String, dynamic>> _discovered = [];
  // Set of selected emails from discovered
  final Set<String> _selectedEmails = {};

  @override
  void initState() {
    super.initState();
    _loadDiscoveredSenders();
  }

  Future<void> _loadDiscoveredSenders() async {
    setState(() => _isLoadingDiscovered = true);
    try {
      final repo = ref.read(mailRepositoryProvider);
      final list = await repo.discoverSenders();
      if (mounted) {
        setState(() {
          _discovered = list;
          // Auto-select likely professors by default
          for (final s in list) {
            final email = (s['address'] ?? s['email'] ?? '').toString().toLowerCase();
            final isLikely = (s['score'] as num? ?? 0) >= 2 || (s['isLikelyProfessor'] == true);
            if (email.isNotEmpty && isLikely) {
              _selectedEmails.add(email);
            }
          }
          _isLoadingDiscovered = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDiscovered = false);
    }
  }

  Future<void> _showAddCustomDialog() async {
    final addressController = TextEditingController();
    final labelController = TextEditingController();
    String kind = 'address'; // 'address' or 'domain'

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Add Sender or Domain',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Email Address'),
                      selected: kind == 'address',
                      onSelected: (val) {
                        if (val) setDialogState(() => kind = 'address');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Domain (@univ.edu)'),
                      selected: kind == 'domain',
                      onSelected: (val) {
                        if (val) setDialogState(() => kind = 'domain');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: kind == 'address' ? 'Email Address' : 'Domain (e.g. @iitmandi.ac.in)',
                    hintText: kind == 'address' ? 'prof.smith@univ.edu' : '@univ.edu',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    labelText: 'Optional Label',
                    hintText: 'e.g. Prof. Smith (Data Science)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = addressController.text.trim();
                final label = labelController.text.trim();
                if (value.isNotEmpty) {
                  final repo = ref.read(mailRepositoryProvider);
                  await repo.addSource(kind, value, label: label.isNotEmpty ? label : null);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (mounted) {
                    SnackbarUtils.showSuccess(context, 'Added $value to sources');
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(mailRepositoryProvider);

      // 1. Save Mode
      await repo.saveMode(_mode);

      // 2. Add selected discovered senders
      for (final s in _discovered) {
        final email = (s['address'] ?? s['email'] ?? '').toString().toLowerCase();
        if (_selectedEmails.contains(email)) {
          final label = s['name'] ?? s['label'];
          await repo.addSource('address', email, label: label);
        }
      }

      // 3. Trigger initial sync
      await repo.triggerSync();

      ref.invalidate(mailSettingsProvider);
      ref.invalidate(emailSourcesProvider);
      ref.invalidate(classTasksProvider);
      ref.invalidate(classNoticesProvider);

      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Settings saved! Checking for class updates...');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to save sources: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final existingSourcesAsync = ref.watch(emailSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isInitialSetup ? 'Choose Email Sources' : 'Email Sender Sources',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Custom Sender',
            onPressed: _showAddCustomDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How should Sentry read your emails?',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose your privacy mode. You can adjust this anytime in settings.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Mode Cards
              _buildModeOption(
                key: 'selected',
                title: 'Selected Senders Only (Recommended)',
                description: 'Sentry only reads emails from approved professors or domains below. Everything else is ignored.',
                icon: Icons.verified_user_outlined,
                isSelected: _mode == 'selected',
              ),
              const SizedBox(height: 12),
              _buildModeOption(
                key: 'all',
                title: 'All Senders',
                description: 'Sentry scans all incoming emails and filters out anything that is not an academic class update.',
                icon: Icons.all_inbox_outlined,
                isSelected: _mode == 'all',
              ),
              const SizedBox(height: 24),

              // Existing sources section
              existingSourcesAsync.when(
                data: (sources) {
                  if (sources.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Senders (${sources.length})',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...sources.map((src) => _buildActiveSourceTile(src, isDark)),
                      const SizedBox(height: 20),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Discovered senders section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Discovered From Last 30 Days',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isLoadingDiscovered)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadDiscoveredSenders,
                      tooltip: 'Re-scan last 30 days',
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoadingDiscovered)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        'Scanning recent messages for professors & courses...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_discovered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No recent senders found or permissions are still activating. You can add professors manually using "+".',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _discovered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = _discovered[i];
                    final address = (item['address'] ?? item['email'] ?? '').toString();
                    final name = (item['name'] ?? '').toString();
                    final count = (item['count'] as num?)?.toInt() ?? 1;
                    final isLikely = (item['score'] as num? ?? 0) >= 2 || item['isLikelyProfessor'] == true;
                    final isChecked = _selectedEmails.contains(address.toLowerCase());

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isChecked
                              ? AppColors.primary
                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedEmails.add(address.toLowerCase());
                            } else {
                              _selectedEmails.remove(address.toLowerCase());
                            }
                          });
                        },
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name.isNotEmpty ? name : address,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLikely) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.sentryGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Likely Professor',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    color: AppColors.sentryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '$address · $count message${count > 1 ? 's' : ''}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 32),

              // Save & Continue Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save & Start Sync',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeOption({
    required String key,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _mode = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? AppColors.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: key,
              groupValue: _mode,
              onChanged: (val) {
                if (val != null) setState(() => _mode = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSourceTile(EmailSource src, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(
            src.isDomain ? Icons.domain : Icons.person_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  src.label?.isNotEmpty == true ? src.label! : src.value,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (src.label?.isNotEmpty == true)
                  Text(
                    src.value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: src.enabled,
            onChanged: (val) async {
              await ref.read(mailRepositoryProvider).toggleSource(src.id, val);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            onPressed: () async {
              await ref.read(mailRepositoryProvider).removeSource(src.id);
            },
          ),
        ],
      ),
    );
  }
}

