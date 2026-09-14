import 'package:academic_assistant/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SplashScreen renders Sentry wordmark and completes animation sequence', (WidgetTester tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          autoNavigate: false,
          onAnimationComplete: () {
            completed = true;
          },
        ),
      ),
    );

    // Verify wordmark is present
    expect(find.text('sentry'), findsOneWidget);

    // Advance animation timeline (2.2s animation + 300ms hold)
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(completed, isTrue);
  });
}
