import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod Notifier for managing active bottom navigation tab index:
/// 0: Home
/// 1: Timetable
/// 2: AI Assistant
/// 3: Courses
class ActiveTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void selectTab(int index) {
    state = index;
  }
}

final activeTabProvider = NotifierProvider<ActiveTabNotifier, int>(
  ActiveTabNotifier.new,
);
