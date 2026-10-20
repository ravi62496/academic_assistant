import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/class_schedule.dart';
import '../models/task.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Notification Channels & IDs
  static const int morningBriefingBaseId = 1010;
  static const int nightlyPreviewBaseId = 1020;
  static const int instantNotificationId = 9998;
  static const int testNotificationId = 9999;

  static const String classChannelId = 'class_reminders';
  static const String classChannelName = 'Class Reminders';
  static const String classChannelDescription = 'Alerts 10 minutes before upcoming classes';

  static const String dailyChannelId = 'daily_briefings';
  static const String dailyChannelName = 'Daily Briefings';
  static const String dailyChannelDescription = 'Morning schedule briefing and nightly next-day preview';

  // Synchronization lock to prevent overlapping cancel/schedule race conditions
  bool _isUpdating = false;
  bool _needsReupdate = false;
  List<ClassSchedule>? _pendingClasses;
  List<Task>? _pendingTasks;
  bool? _pendingClassAlerts;
  bool? _pendingMorningBriefing;
  bool? _pendingNightlyPreview;

  /// Initialize notification plugin, timezones, and system notification channels
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        // Fallback: match by current DateTime offset if exact timezone string isn't in database
        try {
          final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
          tz.Location? matched;
          for (final loc in tz.timeZoneDatabase.locations.values) {
            try {
              if (loc.currentTimeZone.offset == offsetMs) {
                matched = loc;
                break;
              }
            } catch (_) {}
          }
          tz.setLocalLocation(matched ?? tz.getLocation('UTC'));
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      }
    } catch (e) {
      debugPrint('Error initializing timezone: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Register Android notification channels explicitly in NotificationManager
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          classChannelId,
          classChannelName,
          description: classChannelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          dailyChannelId,
          dailyChannelName,
          description: dailyChannelDescription,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    _isInitialized = true;
  }

  /// Request permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      try {
        await androidImplementation.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Exact alarms request notice: $e');
      }
      return granted ?? false;
    }

    final iosImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Check whether notifications are enabled in device settings
  Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) await initialize();

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      return (await androidImplementation.areNotificationsEnabled()) ?? false;
    }

    return true;
  }

  /// Check permissions status summary
  Future<Map<String, bool>> checkPermissionsStatus() async {
    if (!_isInitialized) await initialize();

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    bool notificationsAllowed = true;

    if (androidImplementation != null) {
      notificationsAllowed = (await androidImplementation.areNotificationsEnabled()) ?? false;
    }

    return {
      'notifications': notificationsAllowed,
      'exactAlarms': true,
    };
  }

  /// Parse HH:mm or HH:mm:ss string into [int hour, int minute]
  static List<int> parseTimeString(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return [hour, minute];
      }
    } catch (e) {
      debugPrint('Error parsing time string "$timeStr": $e');
    }
    return [0, 0];
  }

  static String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
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
        return 'Day $dayOfWeek';
    }
  }

  /// Safe zoned schedule helper trying alarmClock -> exactAllowWhileIdle -> inexactAllowWhileIdle
  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    // 1. Try alarmClock mode (highest priority, immune to Doze mode and manufacturer battery restrictions)
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      return;
    } catch (e) {
      debugPrint('alarmClock mode failed for $id, falling back to exactAllowWhileIdle: $e');
    }

    // 2. Fallback to exactAllowWhileIdle
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      return;
    } catch (e) {
      debugPrint('exactAllowWhileIdle mode failed for $id, falling back to inexactAllowWhileIdle: $e');
    }

    // 3. Fallback to inexactAllowWhileIdle
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint('All schedule attempts failed for notification $id: $e');
    }
  }

  /// Schedule 10-minute pre-class reminders for upcoming weekly classes
  Future<void> scheduleClassReminders(List<ClassSchedule> classes) async {
    if (!_isInitialized) await initialize();

    final now = tz.TZDateTime.now(tz.local);

    const androidClassDetails = AndroidNotificationDetails(
      classChannelId,
      classChannelName,
      channelDescription: classChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const notificationDetails = NotificationDetails(
      android: androidClassDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    for (final cs in classes) {
      final timeParts = parseTimeString(cs.startTime);
      final classHour = timeParts[0];
      final classMin = timeParts[1];

      // Calculate class start time in total minutes from midnight
      final classTotalMins = classHour * 60 + classMin;
      final alertTotalMins = classTotalMins - 10;

      int alertHour = alertTotalMins ~/ 60;
      int alertMin = alertTotalMins % 60;
      int dayOffset = 0;

      if (alertTotalMins < 0) {
        // Alert falls on previous day
        alertHour += 24;
        dayOffset = -1;
      }

      // Find upcoming target day of week
      int targetDayOfWeek = cs.dayOfWeek + dayOffset;
      if (targetDayOfWeek < 1) targetDayOfWeek += 7;
      if (targetDayOfWeek > 7) targetDayOfWeek -= 7;

      int daysUntilClass = targetDayOfWeek - now.weekday;
      if (daysUntilClass < 0) daysUntilClass += 7;

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        alertHour,
        alertMin,
      ).add(Duration(days: daysUntilClass));

      // Calculate actual class start date/time
      int daysUntilActualClass = cs.dayOfWeek - now.weekday;
      if (daysUntilActualClass < 0) daysUntilActualClass += 7;

      final classStartDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        classHour,
        classMin,
      ).add(Duration(days: daysUntilActualClass));

      final courseName = cs.course?.name ?? cs.course?.code ?? 'Upcoming Class';
      final roomInfo = (cs.room != null && cs.room!.trim().isNotEmpty)
          ? ' in Room ${cs.room}'
          : '';

      final baseId = (cs.id.hashCode.abs() % 400000) + 2000;
      final oneShotId = baseId;
      final recurringId = baseId + 400000;

      // Case 1: Alert is today and in the future (e.g. class in 15 mins -> alert in 5 mins)
      if (daysUntilClass == 0 && scheduledDate.isAfter(now)) {
        // Schedule exact one-shot alarm today to guarantee immediate firing
        await _zonedScheduleWithFallback(
          id: oneShotId,
          title: 'Class Starting Soon: $courseName',
          body: 'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
        );

        // Schedule weekly recurring alarm starting from next week
        final nextWeekDate = scheduledDate.add(const Duration(days: 7));
        await _zonedScheduleWithFallback(
          id: recurringId,
          title: 'Class Starting Soon: $courseName',
          body: 'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate: nextWeekDate,
          notificationDetails: notificationDetails,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      // Case 2: 10-minute alert time has passed, but class starts within the next 10 minutes today
      else if (daysUntilClass == 0 && scheduledDate.isBefore(now) && classStartDate.isAfter(now)) {
        await _zonedScheduleWithFallback(
          id: oneShotId,
          title: 'Class Starting Soon: $courseName',
          body: 'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate: now.add(const Duration(seconds: 2)),
          notificationDetails: notificationDetails,
        );

        final nextWeekDate = scheduledDate.add(const Duration(days: 7));
        await _zonedScheduleWithFallback(
          id: recurringId,
          title: 'Class Starting Soon: $courseName',
          body: 'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate: nextWeekDate,
          notificationDetails: notificationDetails,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      // Case 3: Today's class and alert have already passed
      else if (daysUntilClass == 0 && scheduledDate.isBefore(now)) {
        final nextWeekDate = scheduledDate.add(const Duration(days: 7));
        await _zonedScheduleWithFallback(
          id: recurringId,
          title: 'Class Starting Soon: $courseName',
          body: 'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate: nextWeekDate,
          notificationDetails: notificationDetails,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      // Case 4: Future day of the week
      else {
        // Schedule one-shot for upcoming occurrence
        await _zonedScheduleWithFallback(
          id: oneShotId,
          title: 'Class Starting Soon: $courseName',
          body: 'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
        );

        // And schedule recurring weekly
        await _zonedScheduleWithFallback(
          id: recurringId,
          title: 'Class Starting Soon: $courseName',
          body: 'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate: scheduledDate.add(const Duration(days: 7)),
          notificationDetails: notificationDetails,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  /// Schedule weekday-specific recurring morning briefings (7:30 AM) & nightly previews (11:30 PM)
  Future<void> _scheduleAllBriefingsAndPreviews({
    required List<ClassSchedule> classes,
    required List<Task> tasks,
    required bool enableMorningBriefing,
    required bool enableNightlyPreview,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    const androidDailyDetails = AndroidNotificationDetails(
      dailyChannelId,
      dailyChannelName,
      channelDescription: dailyChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    const dailyNotificationDetails = NotificationDetails(
      android: androidDailyDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    for (int weekday = 1; weekday <= 7; weekday++) {
      final dayName = _getDayName(weekday);
      final dayClasses = classes.where((c) => c.dayOfWeek == weekday).toList();

      // 1. Morning Briefing (7:30 AM) for this weekday
      if (enableMorningBriefing) {
        int daysUntil = weekday - now.weekday;
        if (daysUntil < 0) daysUntil += 7;

        var morningDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          7,
          30,
        ).add(Duration(days: daysUntil));

        if (morningDate.isBefore(now)) {
          morningDate = morningDate.add(const Duration(days: 7));
        }

        String morningBody;
        if (dayClasses.isEmpty) {
          morningBody = 'No classes scheduled for $dayName. Have a productive day!';
        } else {
          final first = dayClasses.first;
          final courseName = first.course?.name ?? first.course?.code ?? 'First class';
          morningBody = 'You have ${dayClasses.length} class(es) today. Starting with $courseName at ${first.startTime}.';
        }

        final morningId = morningBriefingBaseId + weekday;
        await _zonedScheduleWithFallback(
          id: morningId,
          title: '🌅 $dayName Schedule Briefing',
          body: morningBody,
          scheduledDate: morningDate,
          notificationDetails: dailyNotificationDetails,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }

      // 2. Nightly Preview (11:30 PM / 23:30) for tomorrow
      if (enableNightlyPreview) {
        final tomorrowWeekday = (weekday % 7) + 1;
        final tomorrowName = _getDayName(tomorrowWeekday);
        final tomorrowClasses = classes.where((c) => c.dayOfWeek == tomorrowWeekday).toList();

        int daysUntilNight = weekday - now.weekday;
        if (daysUntilNight < 0) daysUntilNight += 7;

        var nightlyDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          23,
          30,
        ).add(Duration(days: daysUntilNight));

        if (nightlyDate.isBefore(now)) {
          nightlyDate = nightlyDate.add(const Duration(days: 7));
        }

        String nightlyBody;
        if (tomorrowClasses.isEmpty) {
          nightlyBody = 'No classes scheduled for tomorrow ($tomorrowName). Rest well!';
        } else {
          final first = tomorrowClasses.first;
          final courseName = first.course?.name ?? first.course?.code ?? 'First class';
          nightlyBody = 'Tomorrow: ${tomorrowClasses.length} class(es). First up: $courseName at ${first.startTime}.';
        }

        final nightlyId = nightlyPreviewBaseId + weekday;
        await _zonedScheduleWithFallback(
          id: nightlyId,
          title: '🌙 Tomorrow\'s Preview ($tomorrowName)',
          body: nightlyBody,
          scheduledDate: nightlyDate,
          notificationDetails: dailyNotificationDetails,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    if (!_isInitialized) await initialize();
    await _notificationsPlugin.cancelAll();
  }

  /// Re-sync all notifications based on current classes & tasks with concurrency protection
  Future<void> updateAllSchedules({
    required List<ClassSchedule> classes,
    required List<Task> tasks,
    bool enableClassAlerts = true,
    bool enableMorningBriefing = true,
    bool enableNightlyPreview = true,
  }) async {
    if (_isUpdating) {
      // Queue update so it sequentially re-runs after current execution finishes
      _needsReupdate = true;
      _pendingClasses = classes;
      _pendingTasks = tasks;
      _pendingClassAlerts = enableClassAlerts;
      _pendingMorningBriefing = enableMorningBriefing;
      _pendingNightlyPreview = enableNightlyPreview;
      return;
    }

    _isUpdating = true;
    try {
      if (!_isInitialized) await initialize();

      await cancelAll();

      if (enableClassAlerts && classes.isNotEmpty) {
        await scheduleClassReminders(classes);
      }

      await _scheduleAllBriefingsAndPreviews(
        classes: classes,
        tasks: tasks,
        enableMorningBriefing: enableMorningBriefing,
        enableNightlyPreview: enableNightlyPreview,
      );
    } finally {
      _isUpdating = false;
      if (_needsReupdate) {
        _needsReupdate = false;
        final nextClasses = _pendingClasses ?? classes;
        final nextTasks = _pendingTasks ?? tasks;
        final nextAlerts = _pendingClassAlerts ?? enableClassAlerts;
        final nextMorning = _pendingMorningBriefing ?? enableMorningBriefing;
        final nextNightly = _pendingNightlyPreview ?? enableNightlyPreview;
        _pendingClasses = null;
        _pendingTasks = null;
        _pendingClassAlerts = null;
        _pendingMorningBriefing = null;
        _pendingNightlyPreview = null;
        await updateAllSchedules(
          classes: nextClasses,
          tasks: nextTasks,
          enableClassAlerts: nextAlerts,
          enableMorningBriefing: nextMorning,
          enableNightlyPreview: nextNightly,
        );
      }
    }
  }

  /// Show an immediate notification (for class updates, schedule changes, or confirmations)
  Future<void> showInstantNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      classChannelId,
      classChannelName,
      channelDescription: classChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notifId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    await _notificationsPlugin.show(
      notifId,
      title,
      body,
      notificationDetails,
    );
  }

  /// Send immediate test notification
  Future<void> sendTestNotification() async {
    if (!_isInitialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      classChannelId,
      classChannelName,
      channelDescription: classChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      testNotificationId,
      '🔔 Sentry Notifications Active',
      'Class reminders and schedule briefings are working properly on your mobile device!',
      notificationDetails,
    );
  }

  /// Schedule an exact test alarm (default 60 seconds) to verify background waking
  Future<void> scheduleTestAlarm({int secondsFromNow = 60}) async {
    if (!_isInitialized) await initialize();

    final now = tz.TZDateTime.now(tz.local);
    final triggerDate = now.add(Duration(seconds: secondsFromNow));

    await _zonedScheduleWithFallback(
      id: testNotificationId,
      title: '⏰ Alarm Verification Successful!',
      body: 'Exact alarms and background wake-up are working flawlessly on your device.',
      scheduledDate: triggerDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          classChannelId,
          classChannelName,
          channelDescription: classChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
