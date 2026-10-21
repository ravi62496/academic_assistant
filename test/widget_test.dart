import 'package:academic_assistant/models/class_schedule.dart';
import 'package:academic_assistant/models/class_update.dart';
import 'package:academic_assistant/models/course.dart';
import 'package:academic_assistant/models/email_source.dart';
import 'package:academic_assistant/models/mail_settings.dart';
import 'package:academic_assistant/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
  });

  test('Time string parsing test', () {
    final parsedMorning = NotificationService.parseTimeString('07:30');
    expect(parsedMorning[0], 7);
    expect(parsedMorning[1], 30);

    final parsedNight = NotificationService.parseTimeString('23:30:00');
    expect(parsedNight[0], 23);
    expect(parsedNight[1], 30);
  });

  test('formatTimeDisplay converts 24h to 12h AM/PM strings', () {
    expect(NotificationService.formatTimeDisplay('09:00'), '9:00 AM');
    expect(NotificationService.formatTimeDisplay('09:00:00'), '9:00 AM');
    expect(NotificationService.formatTimeDisplay('14:30'), '2:30 PM');
    expect(NotificationService.formatTimeDisplay('14:30:00'), '2:30 PM');
    expect(NotificationService.formatTimeDisplay('00:00'), '12:00 AM');
    expect(NotificationService.formatTimeDisplay('12:00'), '12:00 PM');
    expect(NotificationService.formatTimeDisplay('12:45'), '12:45 PM');
  });

  test('getSubjectShortName: user requested acronym examples', () {
    // 1. "mathematical computation for data science" -> "MCDS"
    expect(
      NotificationService.getSubjectShortName('mathematical computation for data science'),
      'MCDS',
    );
    expect(
      NotificationService.getSubjectShortName('Mathematical Computation for Data Science'),
      'MCDS',
    );

    // 2. "information security and privacy" -> "ISP"
    expect(
      NotificationService.getSubjectShortName('information security and privacy'),
      'ISP',
    );
    expect(
      NotificationService.getSubjectShortName('Information Security and Privacy'),
      'ISP',
    );

    // Other common course acronyms
    expect(
      NotificationService.getSubjectShortName('Data Structures & Algorithms'),
      'DSA',
    );
    expect(
      NotificationService.getSubjectShortName('Database Management Systems'),
      'DMS',
    );
    expect(
      NotificationService.getSubjectShortName('Computer Networks'),
      'CN',
    );
    expect(
      NotificationService.getSubjectShortName('Physics II'),
      'PII',
    );

    // Single word subjects
    expect(
      NotificationService.getSubjectShortName('Physics'),
      'Physics',
    );

    // Pre-existing acronyms or codes
    expect(
      NotificationService.getSubjectShortName('MCDS'),
      'MCDS',
    );
    expect(
      NotificationService.getSubjectShortName('CS101'),
      'CS101',
    );
  });

  test('buildClassListSummary and buildClassListExpanded test', () {
    final classes = [
      ClassSchedule(
        id: '1',
        userId: 'u1',
        courseId: 'c1',
        dayOfWeek: 3,
        startTime: '11:30',
        endTime: '12:30',
        room: '204',
        course: Course(
          id: 'c1',
          userId: 'u1',
          name: 'Information Security and Privacy',
        ),
      ),
      ClassSchedule(
        id: '2',
        userId: 'u1',
        courseId: 'c2',
        dayOfWeek: 3,
        startTime: '09:00',
        endTime: '10:00',
        room: '101',
        course: Course(
          id: 'c2',
          userId: 'u1',
          name: 'Mathematical Computation for Data Science',
        ),
      ),
    ];

    // Summary should sort chronologically and format: "9:00 AM MCDS • 11:30 AM ISP"
    final summary = NotificationService.buildClassListSummary(classes);
    expect(summary, '9:00 AM MCDS • 11:30 AM ISP');

    // Expanded view should have bullet points with rooms
    final expanded = NotificationService.buildClassListExpanded('Header:', classes);
    expect(
      expanded,
      'Header:\n• 9:00 AM - MCDS in Room 101\n• 11:30 AM - ISP in Room 204',
    );
  });

  test('calculateNextAlertTime: future class today schedules 10 minutes prior today', () {
    // 2026-10-21 is a Wednesday (weekday 3)
    final from = tz.TZDateTime(tz.UTC, 2026, 10, 21, 9, 0); // 9:00 AM UTC
    final nextAlert = NotificationService.calculateNextAlertTime(
      dayOfWeek: 3, // Wednesday
      startTime: '10:00',
      from: from,
    );

    expect(nextAlert.weekday, 3);
    expect(nextAlert.day, 21);
    expect(nextAlert.hour, 9);
    expect(nextAlert.minute, 50);
  });

  test('calculateNextAlertTime: past class today rolls over to next week', () {
    final from = tz.TZDateTime(tz.UTC, 2026, 10, 21, 11, 0); // 11:00 AM UTC
    final nextAlert = NotificationService.calculateNextAlertTime(
      dayOfWeek: 3, // Wednesday
      startTime: '10:00', // Alert was at 9:50 AM
      from: from,
    );

    expect(nextAlert.weekday, 3);
    expect(nextAlert.day, 28); // Next Wednesday
    expect(nextAlert.hour, 9);
    expect(nextAlert.minute, 50);
  });

  test('calculateNextAlertTime: future day of week', () {
    final from = tz.TZDateTime(tz.UTC, 2026, 10, 21, 9, 0); // Wednesday
    final nextAlert = NotificationService.calculateNextAlertTime(
      dayOfWeek: 5, // Friday
      startTime: '14:00',
      from: from,
    );

    expect(nextAlert.weekday, 5);
    expect(nextAlert.day, 23); // Friday Oct 23
    expect(nextAlert.hour, 13);
    expect(nextAlert.minute, 50);
  });

  test('ClassUpdate model parsing and category getters', () {
    final quiz = ClassUpdate.fromMap({
      'id': 'up-1',
      'gmail_message_id': 'msg-101',
      'type': 'quiz',
      'title': 'Quiz 2 on Friday',
      'course': 'Data Structures',
      'starts_at': '2026-10-23T10:00:00Z',
      'confidence': 0.95,
      'status': 'confirmed',
      'is_read': false,
    });

    expect(quiz.isTask, isTrue);
    expect(quiz.isNotice, isFalse);
    expect(quiz.typeLabel, 'Quiz');
    expect(quiz.confidence, 0.95);

    final cancelled = ClassUpdate.fromMap({
      'id': 'up-2',
      'gmail_message_id': 'msg-102',
      'type': 'cancelled',
      'title': 'Class Cancelled Today',
      'course': 'Information Security',
      'starts_at': '2026-10-21T11:30:00Z',
      'confidence': 0.99,
      'status': 'confirmed',
      'is_read': false,
    });

    expect(cancelled.isTask, isFalse);
    expect(cancelled.isNotice, isTrue);
    expect(cancelled.typeLabel, 'Cancelled');
  });

  test('EmailSource model getters and domain detection', () {
    final domainSource = EmailSource.fromMap({
      'id': 's1',
      'user_id': 'u1',
      'kind': 'domain',
      'value': '@iitmandi.ac.in',
      'enabled': true,
    });
    expect(domainSource.isDomain, isTrue);
    expect(domainSource.isAddress, isFalse);

    final addressSource = EmailSource.fromMap({
      'id': 's2',
      'user_id': 'u1',
      'kind': 'address',
      'value': 'prof.smith@iitmandi.ac.in',
      'enabled': true,
    });
    expect(addressSource.isDomain, isFalse);
    expect(addressSource.isAddress, isTrue);
  });

  test('MailSettings model parsing and defaults', () {
    final settings = MailSettings.fromMap({
      'user_id': 'u1',
      'mode': 'selected',
      'sync_enabled': true,
    });
    expect(settings.mode, 'selected');
    expect(settings.syncEnabled, isTrue);
    expect(settings.dailyDigest, isFalse);
  });
}
