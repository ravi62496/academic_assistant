import 'package:academic_assistant/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Time string parsing test', () {
    final parsedMorning = NotificationService.parseTimeString('07:30');
    expect(parsedMorning[0], 7);
    expect(parsedMorning[1], 30);

    final parsedNight = NotificationService.parseTimeString('23:30:00');
    expect(parsedNight[0], 23);
    expect(parsedNight[1], 30);
  });
}
