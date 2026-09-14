import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/cache_service.dart';
import '../services/task_service.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService();
});

class TaskNotifier extends AsyncNotifier<List<Task>> {
  static const _cacheKey = 'cached_tasks';
  final _cacheService = CacheService();

  @override
  Future<List<Task>> build() async {
    final service = ref.watch(taskServiceProvider);

    // 1. Instantly load cached tasks if available
    final cached = await _cacheService.getList<Task>(_cacheKey, Task.fromJson);
    if (cached != null && cached.isNotEmpty) {
      state = AsyncValue.data(cached);
    }

    // 2. Fetch fresh tasks from network and update cache
    try {
      final fresh = await service.getTasks();
      await _cacheService.saveList(_cacheKey, fresh, (t) => t.toJson());
      state = AsyncValue.data(fresh);
      return fresh;
    } catch (e) {
      if (cached != null) {
        state = AsyncValue.data(cached);
        return cached;
      }
      rethrow;
    }
  }

  Future<Task> addTask({
    required String title,
    String? description,
    String? courseId,
    DateTime? dueDate,
  }) async {
    final service = ref.read(taskServiceProvider);
    final task = await service.addTask(
      title: title,
      description: description,
      courseId: courseId,
      dueDate: dueDate,
    );
    ref.invalidateSelf();
    return task;
  }

  Future<Task> updateTask(Task task) async {
    final service = ref.read(taskServiceProvider);
    final updated = await service.updateTask(task);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> toggleTaskCompleted(String taskId, bool isCompleted) async {
    final service = ref.read(taskServiceProvider);
    await service.toggleTaskCompleted(taskId, isCompleted);
    ref.invalidateSelf();
  }

  Future<void> deleteTask(String taskId) async {
    final service = ref.read(taskServiceProvider);
    await service.deleteTask(taskId);
    ref.invalidateSelf();
  }

  Future<void> loadTasks() async {
    ref.invalidateSelf();
  }
}

final tasksProvider = AsyncNotifierProvider<TaskNotifier, List<Task>>(
  TaskNotifier.new,
);
