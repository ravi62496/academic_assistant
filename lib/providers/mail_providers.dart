import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_update.dart';
import '../models/email_source.dart';
import '../models/mail_settings.dart';
import '../services/mail_repository.dart';

/// Singleton instance provider for MailRepository
final mailRepositoryProvider = Provider<MailRepository>((ref) {
  return MailRepository();
});

/// Stream of class tasks (quizzes, assignments, exams)
final classTasksProvider = StreamProvider<List<ClassUpdate>>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return repo.tasksStream();
});

/// Stream of class notices (cancellations, postponements, room changes)
final classNoticesProvider = StreamProvider<List<ClassUpdate>>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return repo.noticesStream();
});

/// Stream of items needing user review (lower confidence detections)
final needsReviewProvider = StreamProvider<List<ClassUpdate>>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return repo.needsReviewStream();
});

/// Stream of configured email sources (allowed senders/domains)
final emailSourcesProvider = StreamProvider<List<EmailSource>>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return repo.sourcesStream();
});

/// Stream of user's email intelligence settings
final mailSettingsProvider = StreamProvider<MailSettings?>((ref) {
  final repo = ref.watch(mailRepositoryProvider);
  return repo.settingsStream();
});

/// Provider for unread notice count (for notification badge)
final unreadNoticesCountProvider = Provider<int>((ref) {
  final noticesAsync = ref.watch(classNoticesProvider);
  return noticesAsync.maybeWhen(
    data: (notices) => notices.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Provider for pending review count (for badge in settings/profile)
final pendingReviewCountProvider = Provider<int>((ref) {
  final reviewAsync = ref.watch(needsReviewProvider);
  return reviewAsync.maybeWhen(
    data: (items) => items.length,
    orElse: () => 0,
  );
});

/// Check whether Gmail sync is connected for the user
final isGmailConnectedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(mailRepositoryProvider);
  return await repo.isGmailConnected();
});

