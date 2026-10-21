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

  /// Format 24h HH:mm or HH:mm:ss to a clean readable time string (e.g. "9:00 AM", "2:30 PM")
  static String formatTimeDisplay(String timeStr) {
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toUpperCase().contains('AM') || trimmed.toUpperCase().contains('PM')) {
      return trimmed;
    }
    try {
      final parts = parseTimeString(trimmed);
      final hour24 = parts[0];
      final min = parts[1];
      final period = hour24 >= 12 ? 'PM' : 'AM';
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final minStr = min.toString().padLeft(2, '0');
      return '$hour12:$minStr $period';
    } catch (_) {
      return trimmed;
    }
  }

  /// Generate a concise subject acronym / short name from course name or code
  /// Examples:
  /// - "mathematical computation for data science" -> "MCDS"
  /// - "information security and privacy" -> "ISP"
  /// - "Data Structures & Algorithms" -> "DSA"
  static String getSubjectShortName(String name, [String? code]) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      if (code != null && code.trim().isNotEmpty) {
        return code.trim();
      }
      return 'Class';
    }

    // If already an acronym or short uppercase code (e.g. "MCDS", "CS101", "AI", "DBMS")
    final cleanAlpha = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleanAlpha.length <= 5 && trimmed == trimmed.toUpperCase()) {
      return trimmed;
    }

    // Normalize punctuation and separators into spaces
    final rawTokens = trimmed
        .replaceAll(RegExp(r'[,.:;_/\-&]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (rawTokens.isEmpty) return trimmed;

    // Common stop words to exclude when forming acronyms
    const stopWords = {
      'and', 'for', 'of', 'in', 'to', 'with', 'on', 'at', 'from', 'by',
      'about', 'as', 'into', 'through', 'after', 'over', 'between', 'out',
      'against', 'during', 'without', 'before', 'under', 'around', 'among',
      'the', 'a', 'an', 'or', 'nor', 'but',
    };

    final meaningfulTokens = rawTokens
        .where((t) => !stopWords.contains(t.toLowerCase()))
        .toList();

    final tokensToUse = meaningfulTokens.isNotEmpty ? meaningfulTokens : rawTokens;

    if (tokensToUse.length == 1) {
      final single = tokensToUse.first;
      if (code != null && code.trim().isNotEmpty && code.trim().length <= 6) {
        return code.trim();
      }
      return single;
    }

    // Multiple words: extract initials and keep numbers / roman numerals
    final buffer = StringBuffer();
    for (final token in tokensToUse) {
      if (RegExp(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X|\d+)$', caseSensitive: false).hasMatch(token)) {
        buffer.write(token.toUpperCase());
      } else {
        final match = RegExp(r'[a-zA-Z0-9]').firstMatch(token);
        if (match != null) {
          buffer.write(match.group(0)!.toUpperCase());
        }
      }
    }

    final acronym = buffer.toString().trim();
    return acronym.isNotEmpty ? acronym : trimmed;
  }

  /// Build a compact inline summary of classes: "9:00 AM MCDS • 11:30 AM ISP"
  static String buildClassListSummary(List<ClassSchedule> classesList) {
    if (classesList.isEmpty) return '';
    final sorted = [...classesList]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return sorted.map((cs) {
      final timeStr = formatTimeDisplay(cs.startTime);
      final shortName = getSubjectShortName(
        cs.course?.name ?? cs.course?.code ?? 'Class',
        cs.course?.code,
      );
      return '$timeStr $shortName';
    }).join(' • ');
  }

  /// Build an expanded multi-line breakdown of classes for rich notification views
  static String buildClassListExpanded(String header, List<ClassSchedule> classesList) {
    final sorted = [...classesList]..sort((a, b) => a.startTime.compareTo(b.startTime));
    final lines = <String>[header];
    for (final cs in sorted) {
      final timeStr = formatTimeDisplay(cs.startTime);
      final shortName = getSubjectShortName(
        cs.course?.name ?? cs.course?.code ?? 'Class',
        cs.course?.code,
      );
      final roomInfo = (cs.room != null && cs.room!.trim().isNotEmpty)
          ? ' in Room ${cs.room}'
          : '';
      lines.add('• $timeStr - $shortName$roomInfo');
    }
    return lines.join('\n');
  }

  /// Calculate the next upcoming 10-minute pre-class reminder date/time
  static tz.TZDateTime calculateNextAlertTime({
    required int dayOfWeek,
    required String startTime,
    required tz.TZDateTime from,
  }) {
    final timeParts = parseTimeString(startTime);
    final classHour = timeParts[0];
    final classMin = timeParts[1];

    final classTotalMins = classHour * 60 + classMin;
    final alertTotalMins = classTotalMins - 10;

    int alertHour = alertTotalMins ~/ 60;
    int alertMin = alertTotalMins % 60;
    int dayOffset = 0;

    if (alertTotalMins < 0) {
      alertHour += 24;
      dayOffset = -1;
    }

    int targetDayOfWeek = dayOfWeek + dayOffset;
    if (targetDayOfWeek < 1) targetDayOfWeek += 7;
    if (targetDayOfWeek > 7) targetDayOfWeek -= 7;

    int daysUntilAlert = targetDayOfWeek - from.weekday;
    if (daysUntilAlert < 0) daysUntilAlert += 7;

    var scheduledDate = tz.TZDateTime(
      from.location,
      from.year,
      from.month,
      from.day,
      alertHour,
      alertMin,
    ).add(Duration(days: daysUntilAlert));

    if (scheduledDate.isBefore(from)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
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

    // Deduplicate by class ID to avoid duplicate notifications
    final uniqueClasses = <String, ClassSchedule>{};
    for (final cs in classes) {
      uniqueClasses[cs.id] = cs;
    }

    final usedIds = <int>{};

    for (final cs in uniqueClasses.values) {
      final scheduledDate = calculateNextAlertTime(
        dayOfWeek: cs.dayOfWeek,
        startTime: cs.startTime,
        from: now,
      );

      final shortName = getSubjectShortName(
        cs.course?.name ?? cs.course?.code ?? 'Upcoming Class',
        cs.course?.code,
      );
      final roomInfo = (cs.room != null && cs.room!.trim().isNotEmpty)
          ? ' in Room ${cs.room}'
          : '';
      final timeFormatted = formatTimeDisplay(cs.startTime);

      int notificationId = (cs.id.hashCode.abs() % 800000) + 2000;
      while (usedIds.contains(notificationId)) {
        notificationId++;
      }
      usedIds.add(notificationId);

      // Schedule a single weekly recurring reminder per class
      await _zonedScheduleWithFallback(
        id: notificationId,
        title: 'Class Starting Soon: $shortName',
        body: 'Starts in 10 minutes at $timeFormatted$roomInfo',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
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

        final morningTitle = '🌅 $dayName Schedule Briefing';
        String morningBody;
        String? morningExpanded;

        if (dayClasses.isEmpty) {
          morningBody = 'No classes scheduled for $dayName. Have a productive day!';
        } else {
          final summary = buildClassListSummary(dayClasses);
          morningBody = '${dayClasses.length} class${dayClasses.length == 1 ? '' : 'es'} today: $summary';
          morningExpanded = buildClassListExpanded(
            '📅 $dayName Schedule (${dayClasses.length} class${dayClasses.length == 1 ? '' : 'es'}):',
            dayClasses,
          );
        }

        final morningDetails = NotificationDetails(
          android: AndroidNotificationDetails(
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
            styleInformation: morningExpanded != null
                ? BigTextStyleInformation(
                    morningExpanded,
                    contentTitle: morningTitle,
                    summaryText: '${dayClasses.length} class(es)',
                  )
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        final morningId = morningBriefingBaseId + weekday;
        await _zonedScheduleWithFallback(
          id: morningId,
          title: morningTitle,
          body: morningBody,
          scheduledDate: morningDate,
          notificationDetails: morningDetails,
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

        final nightlyTitle = '🌙 Tomorrow\'s Preview ($tomorrowName)';
        String nightlyBody;
        String? nightlyExpanded;

        if (tomorrowClasses.isEmpty) {
          nightlyBody = 'No classes scheduled for tomorrow ($tomorrowName). Rest well!';
        } else {
          final summary = buildClassListSummary(tomorrowClasses);
          nightlyBody = 'Tomorrow ($tomorrowName): $summary';
          nightlyExpanded = buildClassListExpanded(
            '🌙 Tomorrow\'s Schedule - $tomorrowName (${tomorrowClasses.length} class${tomorrowClasses.length == 1 ? '' : 'es'}):',
            tomorrowClasses,
          );
        }

        final nightlyDetails = NotificationDetails(
          android: AndroidNotificationDetails(
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
            styleInformation: nightlyExpanded != null
                ? BigTextStyleInformation(
                    nightlyExpanded,
                    contentTitle: nightlyTitle,
                    summaryText: '${tomorrowClasses.length} class(es)',
                  )
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        final nightlyId = nightlyPreviewBaseId + weekday;
        await _zonedScheduleWithFallback(
          id: nightlyId,
          title: nightlyTitle,
          body: nightlyBody,
          scheduledDate: nightlyDate,
          notificationDetails: nightlyDetails,
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
