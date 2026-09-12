import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';
import 'task_providers.dart';
import 'timetable_providers.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationSettings {
  final bool classAlertsEnabled;
  final bool morningBriefingEnabled;
  final bool nightlyPreviewEnabled;

  const NotificationSettings({
    this.classAlertsEnabled = true,
    this.morningBriefingEnabled = true,
    this.nightlyPreviewEnabled = true,
  });

  NotificationSettings copyWith({
    bool? classAlertsEnabled,
    bool? morningBriefingEnabled,
    bool? nightlyPreviewEnabled,
  }) {
    return NotificationSettings(
      classAlertsEnabled: classAlertsEnabled ?? this.classAlertsEnabled,
      morningBriefingEnabled: morningBriefingEnabled ?? this.morningBriefingEnabled,
      nightlyPreviewEnabled: nightlyPreviewEnabled ?? this.nightlyPreviewEnabled,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    return const NotificationSettings();
  }

  void toggleClassAlerts(bool enabled) {
    state = state.copyWith(classAlertsEnabled: enabled);
    ref.read(notificationSyncProvider);
  }

  void toggleMorningBriefing(bool enabled) {
    state = state.copyWith(morningBriefingEnabled: enabled);
    ref.read(notificationSyncProvider);
  }

  void toggleNightlyPreview(bool enabled) {
    state = state.copyWith(nightlyPreviewEnabled: enabled);
    ref.read(notificationSyncProvider);
  }
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

/// Provider that listens to timetable & task changes and automatically keeps system notifications in sync
final notificationSyncProvider = Provider<void>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final settings = ref.watch(notificationSettingsProvider);
  final timetableState = ref.watch(timetableProvider);
  final taskState = ref.watch(tasksProvider);

  final classes = timetableState.value ?? [];
  final tasks = taskState.value ?? [];

  notificationService.updateAllSchedules(
    classes: classes,
    tasks: tasks,
    enableClassAlerts: settings.classAlertsEnabled,
    enableMorningBriefing: settings.morningBriefingEnabled,
    enableNightlyPreview: settings.nightlyPreviewEnabled,
  );
});
