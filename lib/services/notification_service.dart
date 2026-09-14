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
  static const int morningBriefingNotificationId = 1001;
  static const int nightlyPreviewNotificationId = 1002;

  static const String classChannelId = 'class_reminders';
  static const String classChannelName = 'Class Reminders';
  static const String classChannelDescription = 'Alerts 10 minutes before upcoming classes';

  static const String dailyChannelId = 'daily_briefings';
  static const String dailyChannelName = 'Daily Briefings';
  static const String dailyChannelDescription = 'Morning schedule briefing and nightly next-day preview';

  /// Initialize notification plugin & timezones
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Error initializing timezone: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
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
    _isInitialized = true;
  }

  /// Request permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    if (!_isInitialized) await initialize();

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
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

  /// Helper to get next occurrence of a given DateTime
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedule 10-minute pre-class reminders for upcoming weekly classes
  Future<void> scheduleClassReminders(List<ClassSchedule> classes) async {
    if (!_isInitialized) await initialize();

    const scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);

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

      final notificationId = (cs.id.hashCode.abs() % 900000) + 2000;

      // If the 10-minute alert time has passed, but class starts within next 10 minutes today
      if (scheduledDate.isBefore(now)) {
        if (classStartDate.isAfter(now)) {
          // Send immediate alert for today's class starting shortly
          try {
            await _notificationsPlugin.zonedSchedule(
              notificationId + 100000,
              'Class Starting Soon: $courseName',
              'Starts in 10 minutes at ${cs.startTime}$roomInfo',
              now.add(const Duration(seconds: 3)),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  classChannelId,
                  classChannelName,
                  channelDescription: classChannelDescription,
                  importance: Importance.max,
                  priority: Priority.high,
                  icon: '@mipmap/ic_launcher',
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              androidScheduleMode: scheduleMode,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          } catch (e) {
            debugPrint('Error scheduling immediate reminder for ${cs.id}: $e');
          }
        }
        // Advance recurring weekly schedule to next week
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          notificationId,
          'Class Starting Soon: $courseName',
          'Starts in 10 minutes at ${cs.startTime}$roomInfo',
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              classChannelId,
              classChannelName,
              channelDescription: classChannelDescription,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      } catch (e) {
        debugPrint('Error scheduling class reminder for ${cs.id}: $e');
        // Fallback to inexact schedule if exact scheduling fails
        try {
          await _notificationsPlugin.zonedSchedule(
            notificationId,
            'Class Starting Soon: $courseName',
            'Starts in 10 minutes at ${cs.startTime}$roomInfo',
            scheduledDate,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                classChannelId,
                classChannelName,
                channelDescription: classChannelDescription,
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (err) {
          debugPrint('Fallback class reminder schedule failed for ${cs.id}: $err');
        }
      }
    }
  }

  /// Schedule Daily Morning Briefing at 7:30 AM
  Future<void> scheduleDailyMorningBriefing({
    required String body,
    int hour = 7,
    int minute = 30,
  }) async {
    if (!_isInitialized) await initialize();

    final scheduledDate = _nextInstanceOfTime(hour, minute);

    try {
      await _notificationsPlugin.zonedSchedule(
        morningBriefingNotificationId,
        '🌅 Good Morning! Today\'s Schedule',
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            dailyChannelId,
            dailyChannelName,
            channelDescription: dailyChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling morning briefing with exact mode: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          morningBriefingNotificationId,
          '🌅 Good Morning! Today\'s Schedule',
          body,
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              dailyChannelId,
              dailyChannelName,
              channelDescription: dailyChannelDescription,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (err) {
        debugPrint('Fallback scheduling morning briefing failed: $err');
      }
    }
  }

  /// Schedule Nightly Preview at 11:30 PM (23:30)
  Future<void> scheduleNightlyPreview({
    required String body,
    int hour = 23,
    int minute = 30,
  }) async {
    if (!_isInitialized) await initialize();

    final scheduledDate = _nextInstanceOfTime(hour, minute);

    try {
      await _notificationsPlugin.zonedSchedule(
        nightlyPreviewNotificationId,
        '🌙 Tomorrow\'s Schedule Preview',
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            dailyChannelId,
            dailyChannelName,
            channelDescription: dailyChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Error scheduling nightly preview with exact mode: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          nightlyPreviewNotificationId,
          '🌙 Tomorrow\'s Schedule Preview',
          body,
          scheduledDate,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              dailyChannelId,
              dailyChannelName,
              channelDescription: dailyChannelDescription,
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (err) {
        debugPrint('Fallback scheduling nightly preview failed: $err');
      }
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAll() async {
    if (!_isInitialized) await initialize();
    await _notificationsPlugin.cancelAll();
  }

  /// Re-sync all notifications based on current classes & tasks
  Future<void> updateAllSchedules({
    required List<ClassSchedule> classes,
    required List<Task> tasks,
    bool enableClassAlerts = true,
    bool enableMorningBriefing = true,
    bool enableNightlyPreview = true,
  }) async {
    if (!_isInitialized) await initialize();

    await cancelAll();

    if (enableClassAlerts && classes.isNotEmpty) {
      await scheduleClassReminders(classes);
    }

    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final tomorrowWeekday = (todayWeekday % 7) + 1;

    // Build Morning Briefing text
    if (enableMorningBriefing) {
      final todayClasses = classes.where((c) => c.dayOfWeek == todayWeekday).toList();
      final todayTasks = tasks.where((t) {
        if (t.dueDate == null || t.isCompleted) return false;
        return t.dueDate!.year == now.year &&
            t.dueDate!.month == now.month &&
            t.dueDate!.day == now.day;
      }).toList();

      String morningBody;
      if (todayClasses.isEmpty && todayTasks.isEmpty) {
        morningBody = 'No classes or pending tasks scheduled for today. Have a great day!';
      } else {
        final classStr = todayClasses.isNotEmpty
            ? '${todayClasses.length} class(es)'
            : 'No classes';
        final taskStr = todayTasks.isNotEmpty
            ? '${todayTasks.length} task(s) due'
            : 'no pending tasks';
        morningBody = 'You have $classStr and $taskStr today.';
      }

      await scheduleDailyMorningBriefing(body: morningBody);
    }

    // Build Nightly Preview text
    if (enableNightlyPreview) {
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowClasses = classes.where((c) => c.dayOfWeek == tomorrowWeekday).toList();
      final tomorrowTasks = tasks.where((t) {
        if (t.dueDate == null || t.isCompleted) return false;
        return t.dueDate!.year == tomorrow.year &&
            t.dueDate!.month == tomorrow.month &&
            t.dueDate!.day == tomorrow.day;
      }).toList();

      String nightlyBody;
      if (tomorrowClasses.isEmpty && tomorrowTasks.isEmpty) {
        nightlyBody = 'No classes or tasks scheduled for tomorrow.';
      } else {
        final classStr = tomorrowClasses.isNotEmpty
            ? '${tomorrowClasses.length} class(es)'
            : 'No classes';
        final taskStr = tomorrowTasks.isNotEmpty
            ? '${tomorrowTasks.length} task(s) due'
            : 'no tasks';
        nightlyBody = 'Tomorrow: $classStr, $taskStr.';
      }

      await scheduleNightlyPreview(body: nightlyBody);
    }
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
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      9999,
      'Sentry Notifications Active',
      'Class reminders and daily briefings are set up!',
      notificationDetails,
    );
  }
}
