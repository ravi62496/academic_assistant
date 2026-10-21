import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_update.dart';
import '../models/email_source.dart';
import '../models/mail_settings.dart';

class MailRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Stream tasks (quizzes, exams, assignments)
  Stream<List<ClassUpdate>> tasksStream() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return _client
        .from('class_updates')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('starts_at')
        .map((rows) => rows
            .map(ClassUpdate.fromMap)
            .where((u) => u.isTask && u.status != 'dismissed' && u.status != 'pending')
            .toList());
  }

  /// Stream class notices (cancellations, postponements, room changes)
  Stream<List<ClassUpdate>> noticesStream() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return _client
        .from('class_updates')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map(ClassUpdate.fromMap)
            .where((u) => !u.isTask && u.status != 'dismissed')
            .toList());
  }

  /// Stream items needing manual review (confidence 0.5 - 0.8)
  Stream<List<ClassUpdate>> needsReviewStream() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return _client
        .from('class_updates')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows
            .map(ClassUpdate.fromMap)
            .where((u) => u.status == 'pending')
            .toList());
  }

  /// Stream user's configured email sources
  Stream<List<EmailSource>> sourcesStream() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return _client
        .from('email_sources')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at')
        .map((rows) => rows.map(EmailSource.fromMap).toList());
  }

  /// Stream user's mail settings
  Stream<MailSettings?> settingsStream() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return _client
        .from('mail_settings')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) => rows.isNotEmpty ? MailSettings.fromMap(rows.first) : null);
  }

  /// Update an item's status ('confirmed', 'dismissed', 'done')
  Future<void> setStatus(String id, String status) async {
    await _client.from('class_updates').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Update and confirm an item from review queue
  Future<void> updateAndConfirm(String id, {String? title, String? course, String? type}) async {
    final Map<String, dynamic> updates = {
      'status': 'confirmed',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (title != null && title.isNotEmpty) updates['title'] = title;
    if (course != null && course.isNotEmpty) updates['course'] = course;
    if (type != null && type.isNotEmpty) updates['type'] = type;

    await _client.from('class_updates').update(updates).eq('id', id);
  }

  /// Mark notice as read
  Future<void> markRead(String id) async {
    await _client.from('class_updates').update({
      'is_read': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Mark all unread notices as read
  Future<void> markAllNoticesRead() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client
        .from('class_updates')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Update sender mode ('selected' vs 'all')
  Future<void> saveMode(String mode) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client.from('mail_settings').upsert({
      'user_id': userId,
      'mode': mode,
    });
  }

  /// Add an allowed sender (address or domain)
  Future<void> addSource(String kind, String value, {String? label}) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client.from('email_sources').upsert({
      'user_id': userId,
      'kind': kind,
      'value': value.toLowerCase().trim(),
      'label': label,
      'enabled': true,
    });
  }

  /// Toggle source enabled state
  Future<void> toggleSource(String id, bool enabled) async {
    await _client.from('email_sources').update({'enabled': enabled}).eq('id', id);
  }

  /// Remove a sender source
  Future<void> removeSource(String id) async {
    await _client.from('email_sources').delete().eq('id', id);
  }

  /// Toggle sync enabled
  Future<void> toggleSyncEnabled(bool enabled) async {
    final userId = currentUserId;
    if (userId == null) return;
    await _client.from('mail_settings').update({'sync_enabled': enabled}).eq('user_id', userId);
  }

  /// Discover candidate senders from last 30 days
  Future<List<Map<String, dynamic>>> discoverSenders() async {
    try {
      final res = await _client.functions.invoke('discover-senders');
      if (res.data != null && res.data['senders'] is List) {
        return List<Map<String, dynamic>>.from(res.data['senders']);
      }
    } catch (e) {
      debugPrint('discoverSenders error: $e');
    }
    return [];
  }

  /// Trigger manual mail sync immediately
  Future<int> triggerSync() async {
    try {
      final res = await _client.functions.invoke('sync-mail', body: {
        'user_id': currentUserId,
      });
      return (res.data?['processed'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('triggerSync error: $e');
      return 0;
    }
  }

  /// Check if Gmail is connected
  Future<bool> isGmailConnected() async {
    final userId = currentUserId;
    if (userId == null) return false;
    try {
      final res = await _client
          .from('mail_settings')
          .select('sync_enabled')
          .eq('user_id', userId)
          .maybeSingle();
      return res != null;
    } catch (_) {
      return false;
    }
  }

  /// One-tap: Disconnect Gmail, revoke Google token, and purge all email data
  Future<void> disconnectAndPurgeData() async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await _client.functions.invoke('connect-gmail', body: {
        'action': 'disconnect',
      });
    } catch (e) {
      debugPrint('Error invoking disconnect function: $e');
    }
    // Also explicitly purge client-side accessible tables
    await _client.from('class_updates').delete().eq('user_id', userId);
    await _client.from('email_sources').delete().eq('user_id', userId);
    await _client.from('mail_settings').delete().eq('user_id', userId);
  }
}
