import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const _kClassAlerts = 'setting_notif_class_alerts';
  static const _kMorningBriefing = 'setting_notif_morning_briefing';
  static const _kNightlyPreview = 'setting_notif_nightly_preview';

  @override
  NotificationSettings build() {
    _loadFromPrefs();
    return const NotificationSettings();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final classAlerts = prefs.getBool(_kClassAlerts) ?? true;
      final morning = prefs.getBool(_kMorningBriefing) ?? true;
      final nightly = prefs.getBool(_kNightlyPreview) ?? true;
      state = NotificationSettings(
        classAlertsEnabled: classAlerts,
        morningBriefingEnabled: morning,
        nightlyPreviewEnabled: nightly,
      );
    } catch (_) {}
  }

  void toggleClassAlerts(bool enabled) {
    state = state.copyWith(classAlertsEnabled: enabled);
    _persist(_kClassAlerts, enabled);
  }

  void toggleMorningBriefing(bool enabled) {
    state = state.copyWith(morningBriefingEnabled: enabled);
    _persist(_kMorningBriefing, enabled);
  }

  void toggleNightlyPreview(bool enabled) {
    state = state.copyWith(nightlyPreviewEnabled: enabled);
    _persist(_kNightlyPreview, enabled);
  }

  Future<void> _persist(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
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

  // Guard: Avoid clearing or scheduling notifications while timetable or tasks are still in initial loading state
  if (!timetableState.hasValue && !taskState.hasValue) {
    return;
  }

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
