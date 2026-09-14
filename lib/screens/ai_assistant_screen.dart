import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/course_providers.dart';
import '../providers/timetable_providers.dart';
import '../services/ai_action_executor.dart';
import '../services/ai_assistant_service.dart';
import '../theme/app_colors.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/ai_node_icon.dart';

enum ActionStatus { pending, approved, rejected, executing }

class ChatMessageItem {
  final String id;
  final bool isUser;
  final String text;
  final Uint8List? imageBytes;
  final List<ProposedActionItem>? proposedActions;
  final DateTime timestamp;

  ChatMessageItem({
    required this.id,
    required this.isUser,
    required this.text,
    this.imageBytes,
    this.proposedActions,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ProposedActionItem {
  final String toolName;
  final Map<String, dynamic> arguments;
  ActionStatus status;
  String? resultSummary;

  ProposedActionItem({
    required this.toolName,
    required this.arguments,
    this.status = ActionStatus.pending,
    this.resultSummary,
  });
}

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final List<ChatMessageItem> _messages = [];
  final List<Map<String, dynamic>> _apiHistory = [];

  Uint8List? _selectedImageBytes;
  String? _selectedImageBase64;
  bool _isLoading = false;

  final AiAssistantService _aiService = AiAssistantService();
  final AiActionExecutor _actionExecutor = AiActionExecutor();

  @override
  void initState() {
    super.initState();
    // Default welcome message
    _messages.add(
      ChatMessageItem(
        id: 'welcome',
        isUser: false,
        text:
            'Hello! I am your AI Scheduling Assistant.\n\nYou can ask me to reschedule classes, add courses, cancel sessions, or snap a photo of your printed timetable to import all classes automatically!',
      ),
    );

    // Load persistent chat history from Supabase
    _loadPersistentChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPersistentChatHistory() async {
    final historyRows = await _aiService.loadChatHistory();
    if (!mounted) return;

    if (historyRows.isNotEmpty) {
      final loadedMessages = <ChatMessageItem>[];
      final loadedApiHistory = <Map<String, dynamic>>[];

      for (int i = 0; i < historyRows.length; i++) {
        final row = historyRows[i];
        final role = row['role'] as String? ?? 'user';
        final isUser = role == 'user';
        final content = row['content'] as String? ?? '';
        final rawToolCalls = row['tool_calls'] as List<dynamic>?;

        List<ProposedActionItem>? proposedActions;
        if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
          proposedActions = rawToolCalls.map((tc) {
            final map = tc as Map<String, dynamic>;
            return ProposedActionItem(
              toolName: map['name'] ?? map['toolName'] ?? '',
              arguments: Map<String, dynamic>.from(map['arguments'] ?? {}),
            );
          }).toList();
        }

        loadedMessages.add(ChatMessageItem(
          id: row['id']?.toString() ?? i.toString(),
          isUser: isUser,
          text: content,
          proposedActions: proposedActions,
          timestamp: row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null,
        ));

        loadedApiHistory.add({
          'role': role,
          'content': content,
        });
      }

      setState(() {
        _messages.clear();
        _messages.addAll(loadedMessages);
        _apiHistory.clear();
        _apiHistory.addAll(loadedApiHistory);
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageBase64 = base64Str;
        });
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageBase64 = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImageBase64 == null) return;

    final userImageBytes = _selectedImageBytes;
    final userImageBase64 = _selectedImageBase64;
    final userText = text;

    _messageController.clear();
    setState(() {
      _selectedImageBytes = null;
      _selectedImageBase64 = null;
      _isLoading = true;

      _messages.add(
        ChatMessageItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          isUser: true,
          text: userText,
          imageBytes: userImageBytes,
        ),
      );
    });

    _scrollToBottom();

    // Persist user message in Supabase
    _aiService.saveChatMessage(
      role: 'user',
      content: userText.isNotEmpty ? userText : 'Attached timetable image for extraction.',
    );

    final courses = ref.read(coursesProvider).value ?? [];
    final classes = ref.read(timetableProvider).value ?? [];

    try {
      final response = await _aiService.sendMessage(
        message: userText,
        imageBase64: userImageBase64,
        courses: courses,
        classes: classes,
        history: _apiHistory,
      );

      if (userText.isNotEmpty || userImageBase64 != null) {
        _apiHistory.add({
          'role': 'user',
          'content': userText.isNotEmpty
              ? userText
              : 'Analyze timetable image and extract classes.',
        });
      }

      final proposedActions = response.toolCalls
          .map((tc) => ProposedActionItem(
                toolName: tc.name,
                arguments: Map<String, dynamic>.from(tc.arguments),
              ))
          .toList();

      final replyText = response.text ??
          (proposedActions.isNotEmpty
              ? 'I have prepared the requested schedule changes. Please review and confirm below:'
              : 'No actions were identified.');

      _apiHistory.add({
        'role': 'assistant',
        'content': replyText,
      });

      // Persist assistant message in Supabase
      final toolCallsJson = response.toolCalls.map((tc) => tc.toJson()).toList();
      _aiService.saveChatMessage(
        role: 'assistant',
        content: replyText,
        toolCalls: toolCallsJson.isNotEmpty ? toolCallsJson : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessageItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              isUser: false,
              text: replyText,
              proposedActions: proposedActions.isNotEmpty ? proposedActions : null,
            ),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add(
            ChatMessageItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              isUser: false,
              text: 'Sorry, I ran into an error processing your request: $e',
            ),
          );
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _approveAction(ProposedActionItem action) async {
    setState(() {
      action.status = ActionStatus.executing;
    });

    try {
      final summary = await _actionExecutor.execute(action.toolName, action.arguments);

      ref.invalidate(coursesProvider);
      ref.invalidate(timetableProvider);

      if (mounted) {
        setState(() {
          action.status = ActionStatus.approved;
          action.resultSummary = summary;
        });
        SnackbarUtils.showSuccess(context, summary);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          action.status = ActionStatus.pending;
        });
        SnackbarUtils.showError(context, 'Failed to execute action: $e');
      }
    }
  }

  void _rejectAction(ProposedActionItem action) {
    setState(() {
      action.status = ActionStatus.rejected;
      action.resultSummary = 'Action cancelled by user.';
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.aiAccent),
              title: Text('Pick Timetable Photo from Gallery', style: GoogleFonts.plusJakartaSans()),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.aiAccent),
              title: Text('Take Photo with Camera', style: GoogleFonts.plusJakartaSans()),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditImportDialog(ProposedActionItem action) async {
    final rawEntries = action.arguments['entries'] as List<dynamic>? ?? [];
    List<Map<String, dynamic>> entriesList =
        rawEntries.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditImportEntriesDialog(initialEntries: entriesList),
    );

    if (result != null) {
      setState(() {
        action.arguments['entries'] = result;
      });
      await _approveAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const AiNodeIcon(size: 22, color: AppColors.aiAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Scheduling Assistant',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'AI Mode • Persistent History',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.aiAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear Chat History',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              await _aiService.clearChatHistory();
              setState(() {
                _messages.clear();
                _apiHistory.clear();
                _messages.add(
                  ChatMessageItem(
                    id: 'welcome_new',
                    isUser: false,
                    text: 'Chat history cleared. How can I help you with your schedule today?',
                  ),
                );
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // AI Mode Header Indicator Pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.aiAccent.withValues(alpha: 0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.aiAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'AI Mode Active — Changes require approval before updating database',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.aiAccent,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, isDark);
              },
            ),
          ),

          // Smooth Typing / Thinking Indicator
          if (_isLoading) _buildThinkingIndicator(isDark),

          // Image Attachment Preview Bar
          if (_selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.darkSurface : Colors.grey.shade200,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timetable Image Attached',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Tap send to extract classes automatically',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove image',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _clearSelectedImage,
                  ),
                ],
              ),
            ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: AppColors.aiAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.aiAccent.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach Timetable Photo',
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.aiAccent,
                    ),
                    onPressed: _isLoading ? null : _showImageSourceSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isLoading,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _selectedImageBytes != null
                            ? 'Add instructions or tap Send...'
                            : 'e.g. Move Tuesday DBMS to 4pm',
                        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: AppColors.aiAccent.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: AppColors.aiAccent,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkInputBackground
                            : Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Send Message',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.aiAccent,
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: _isLoading ? null : _handleSendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.aiAccent.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AiNodeIcon(size: 16, color: AppColors.aiAccent, animate: true),
                const SizedBox(width: 10),
                Text(
                  'AI Assistant is processing schedule...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.aiAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageItem msg, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.aiAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.aiAccent.withValues(alpha: 0.4), width: 1),
              ),
              child: const AiNodeIcon(size: 16, color: AppColors.aiAccent, animate: false),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? AppColors.aiAccent
                        : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
                      bottomRight: Radius.circular(msg.isUser ? 4 : 18),
                    ),
                    border: Border.all(
                      color: msg.isUser
                          ? AppColors.aiAccent
                          : (isDark
                              ? AppColors.aiAccent.withValues(alpha: 0.25)
                              : AppColors.lightBorder),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.imageBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: Image.memory(
                              msg.imageBytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (msg.text.isNotEmpty)
                        Text(
                          msg.text,
                          style: GoogleFonts.plusJakartaSans(
                            color: msg.isUser
                                ? Colors.white
                                : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                    ],
                  ),
                ),

                // Proposed Action Confirmation Cards (Animated Expand-In)
                if (msg.proposedActions != null && msg.proposedActions!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: msg.proposedActions!
                          .map((action) => _buildActionCard(action, isDark))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 15,
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade300,
              child: Icon(
                Icons.person,
                color: isDark ? AppColors.darkTextPrimary : Colors.grey.shade700,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(ProposedActionItem action, bool isDark) {
    final title = _getActionTitle(action.toolName);
    final details = _getActionDetailsList(action.toolName, action.arguments);
    final isImport = action.toolName == 'import_schedule_from_image';

    Color cardBorderColor;
    switch (action.status) {
      case ActionStatus.approved:
        cardBorderColor = AppColors.success;
        break;
      case ActionStatus.rejected:
        cardBorderColor = AppColors.error;
        break;
      default:
        cardBorderColor = AppColors.aiAccent;
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.aiAccent.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getActionIcon(action.toolName),
                size: 18,
                color: AppColors.aiAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),

              if (action.status == ActionStatus.approved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Approved',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else if (action.status == ActionStatus.rejected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel_rounded, size: 14, color: AppColors.error),
                      const SizedBox(width: 4),
                      Text(
                        'Rejected',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          ...details.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${d.key}: ',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      d.value,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (action.resultSummary != null) ...[
            const SizedBox(height: 6),
            Text(
              action.resultSummary!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: action.status == ActionStatus.approved
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
          ],

          if (action.status == ActionStatus.pending ||
              action.status == ActionStatus.executing) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isImport)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: Text('Review Extracted', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                      onPressed: action.status == ActionStatus.executing
                          ? null
                          : () => _showEditImportDialog(action),
                    ),
                  
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: action.status == ActionStatus.executing
                        ? null
                        : () => _rejectAction(action),
                    child: Text('Reject', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  _TactileApproveButton(
                    isExecuting: action.status == ActionStatus.executing,
                    label: isImport ? 'Import All' : 'Approve',
                    onPressed: action.status == ActionStatus.executing
                        ? null
                        : () => _approveAction(action),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getActionTitle(String toolName) {
    switch (toolName) {
      case 'add_course':
        return 'Proposed Action: Add Course';
      case 'update_course':
        return 'Proposed Action: Update Course';
      case 'delete_course':
        return 'Proposed Action: Delete Course';
      case 'add_class':
        return 'Proposed Action: Add Class Schedule';
      case 'update_class':
        return 'Proposed Action: Update Class Schedule';
      case 'delete_class':
        return 'Proposed Action: Delete Class Schedule';
      case 'add_override':
        return 'Proposed Action: Schedule Override';
      case 'import_schedule_from_image':
        return 'Proposed Action: Import Timetable';
      default:
        return 'Proposed Action: $toolName';
    }
  }

  IconData _getActionIcon(String toolName) {
    switch (toolName) {
      case 'add_course':
      case 'update_course':
        return Icons.school_outlined;
      case 'delete_course':
      case 'delete_class':
        return Icons.delete_outline;
      case 'add_class':
      case 'update_class':
        return Icons.calendar_today_outlined;
      case 'add_override':
        return Icons.edit_calendar_outlined;
      case 'import_schedule_from_image':
        return Icons.document_scanner_outlined;
      default:
        return Icons.extension_outlined;
    }
  }

  List<MapEntry<String, String>> _getActionDetailsList(
      String toolName, Map<String, dynamic> args) {
    final list = <MapEntry<String, String>>[];

    switch (toolName) {
      case 'add_course':
        if (args['name'] != null) list.add(MapEntry('Course Name', args['name'].toString()));
        if (args['code'] != null) list.add(MapEntry('Course Code', args['code'].toString()));
        if (args['professor'] != null) list.add(MapEntry('Professor', args['professor'].toString()));
        break;

      case 'update_course':
        if (args['course_id'] != null) list.add(MapEntry('Course ID', args['course_id'].toString()));
        if (args['name'] != null) list.add(MapEntry('New Name', args['name'].toString()));
        if (args['code'] != null) list.add(MapEntry('New Code', args['code'].toString()));
        if (args['professor'] != null) list.add(MapEntry('New Professor', args['professor'].toString()));
        break;

      case 'delete_course':
        if (args['course_id'] != null) list.add(MapEntry('Course ID', args['course_id'].toString()));
        break;

      case 'add_class':
        if (args['course_id'] != null) list.add(MapEntry('Course ID', args['course_id'].toString()));
        if (args['day_of_week'] != null) {
          list.add(MapEntry('Day', _getDayName((args['day_of_week'] as num).toInt())));
        }
        if (args['start_time'] != null && args['end_time'] != null) {
          list.add(MapEntry('Time', '${args['start_time']} - ${args['end_time']}'));
        }
        if (args['room'] != null) list.add(MapEntry('Room', args['room'].toString()));
        break;

      case 'update_class':
        if (args['class_id'] != null) list.add(MapEntry('Class ID', args['class_id'].toString()));
        if (args['day_of_week'] != null) {
          list.add(MapEntry('New Day', _getDayName((args['day_of_week'] as num).toInt())));
        }
        if (args['start_time'] != null || args['end_time'] != null) {
          list.add(MapEntry('New Time', '${args['start_time'] ?? ''} - ${args['end_time'] ?? ''}'));
        }
        if (args['room'] != null) list.add(MapEntry('New Room', args['room'].toString()));
        break;

      case 'delete_class':
        if (args['class_id'] != null) list.add(MapEntry('Class ID', args['class_id'].toString()));
        break;

      case 'add_override':
        if (args['class_id'] != null) list.add(MapEntry('Class ID', args['class_id'].toString()));
        if (args['date'] != null) list.add(MapEntry('Date', args['date'].toString()));
        if (args['type'] != null) list.add(MapEntry('Type', args['type'].toString().toUpperCase()));
        if (args['new_start_time'] != null || args['new_end_time'] != null) {
          list.add(MapEntry('Rescheduled Time', '${args['new_start_time'] ?? ''} - ${args['new_end_time'] ?? ''}'));
        }
        if (args['new_room'] != null) list.add(MapEntry('New Room', args['new_room'].toString()));
        break;

      case 'import_schedule_from_image':
        final entries = args['entries'] as List<dynamic>? ?? [];
        list.add(MapEntry('Total Detected Classes', '${entries.length} entries'));
        for (int i = 0; i < entries.length && i < 5; i++) {
          final entry = entries[i] as Map<String, dynamic>;
          final cName = entry['course_name'] ?? 'Class';
          final day = _getDayName((entry['day_of_week'] as num? ?? 1).toInt());
          final time = '${entry['start_time'] ?? ''} - ${entry['end_time'] ?? ''}';
          final roomStr = entry['room'] != null ? ' (${entry['room']})' : '';
          list.add(MapEntry('Entry ${i + 1}', '$cName ($day @ $time$roomStr)'));
        }
        if (entries.length > 5) {
          list.add(MapEntry('And more...', '+${entries.length - 5} additional classes'));
        }
        break;

      default:
        args.forEach((key, val) => list.add(MapEntry(key, val.toString())));
        break;
    }

    return list;
  }

  static String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Day $day';
    }
  }
}

class _TactileApproveButton extends StatefulWidget {
  final bool isExecuting;
  final String label;
  final VoidCallback? onPressed;

  const _TactileApproveButton({
    required this.isExecuting,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_TactileApproveButton> createState() => _TactileApproveButtonState();
}

class _TactileApproveButtonState extends State<_TactileApproveButton> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    setState(() => _scale = 0.94);
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.of(context).disableAnimations;

    Widget btn = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: widget.isExecuting
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.check_rounded, size: 16),
      label: Text(
        widget.label,
        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      onPressed: widget.onPressed,
    );

    if (disableAnimations || widget.onPressed == null) {
      return btn;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: btn,
      ),
    );
  }
}

class _EditImportEntriesDialog extends StatefulWidget {
  final List<Map<String, dynamic>> initialEntries;

  const _EditImportEntriesDialog({required this.initialEntries});

  @override
  State<_EditImportEntriesDialog> createState() => _EditImportEntriesDialogState();
}

class _EditImportEntriesDialogState extends State<_EditImportEntriesDialog> {
  late List<Map<String, dynamic>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.initialEntries.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.aiAccent),
          const SizedBox(width: 8),
          Text(
            'Review Extracted Classes',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: _entries.isEmpty
            ? const Center(child: Text('No entries to import.'))
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _entries.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (ctx, index) {
                  final entry = _entries[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.aiAccent.withValues(alpha: 0.15),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.aiAccent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          children: [
                            TextFormField(
                              initialValue: entry['course_name']?.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Course Name',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (val) => entry['course_name'] = val,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: (entry['day_of_week'] as num? ?? 1).toInt(),
                                    decoration: const InputDecoration(
                                      labelText: 'Day',
                                      isDense: true,
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 1, child: Text('Mon')),
                                      DropdownMenuItem(value: 2, child: Text('Tue')),
                                      DropdownMenuItem(value: 3, child: Text('Wed')),
                                      DropdownMenuItem(value: 4, child: Text('Thu')),
                                      DropdownMenuItem(value: 5, child: Text('Fri')),
                                      DropdownMenuItem(value: 6, child: Text('Sat')),
                                      DropdownMenuItem(value: 7, child: Text('Sun')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) entry['day_of_week'] = val;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: entry['start_time']?.toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'Start Time',
                                      isDense: true,
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (val) => entry['start_time'] = val,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: entry['end_time']?.toString(),
                                    decoration: const InputDecoration(
                                      labelText: 'End Time',
                                      isDense: true,
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    onChanged: (val) => entry['end_time'] = val,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              initialValue: entry['room']?.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Room (Optional)',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onChanged: (val) => entry['room'] = val,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove entry',
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        onPressed: () {
                          setState(() {
                            _entries.removeAt(index);
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(_entries),
          child: const Text('Confirm & Save'),
        ),
      ],
    );
  }
}
