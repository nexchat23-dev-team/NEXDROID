import 'package:flutter/material.dart';

class ActiveTask {
  final String id;
  final String name;
  final String category; // Game Loop, Service, Listener, Animation
  final DateTime startTime;
  final VoidCallback? onCancel;
  double cpuUsage; // Simulated percentage
  double memoryMB; // Simulated megabytes

  ActiveTask({
    required this.id,
    required this.name,
    required this.category,
    required this.startTime,
    this.onCancel,
    this.cpuUsage = 0.0,
    this.memoryMB = 0.0,
  });
}

class ActiveOperationsRegistry {
  static final ActiveOperationsRegistry instance = ActiveOperationsRegistry._internal();
  ActiveOperationsRegistry._internal() {
    // Register default system services
    register('supabase_presence', 'Supabase Gamer Presence Syncer', 'Service', cpuUsage: 0.8, memoryMB: 12.4);
    register('firebase_auth_sync', 'Firebase Auth State Stream', 'Listener', cpuUsage: 0.2, memoryMB: 6.1);
    register('gps_tracker', 'GPS Anomaly Geo-Locator', 'Service', cpuUsage: 1.4, memoryMB: 18.2);
    register('ollama_llm_listener', 'Ollama Local LLM Background Daemon', 'Service', cpuUsage: 0.1, memoryMB: 245.0);
    register('battery_saver_daemon', 'Smart Battery Level Optimizer', 'Service', cpuUsage: 0.4, memoryMB: 4.8);
    register('notification_dispatcher', 'Local System Notification Service', 'Service', cpuUsage: 0.3, memoryMB: 8.2);
  }

  final List<ActiveTask> _tasks = [];
  final ValueNotifier<List<ActiveTask>> tasksNotifier = ValueNotifier<List<ActiveTask>>([]);

  List<ActiveTask> get tasks => List.unmodifiable(_tasks);

  void register(
    String id,
    String name,
    String category, {
    VoidCallback? onCancel,
    double cpuUsage = 1.2,
    double memoryMB = 15.0,
  }) {
    // Avoid double registration
    _tasks.removeWhere((t) => t.id == id);
    _tasks.add(ActiveTask(
      id: id,
      name: name,
      category: category,
      startTime: DateTime.now(),
      onCancel: onCancel,
      cpuUsage: cpuUsage,
      memoryMB: memoryMB,
    ));
    _notify();
  }

  void updateUsage(String id, double cpu, double mem) {
    for (var task in _tasks) {
      if (task.id == id) {
        task.cpuUsage = cpu;
        task.memoryMB = mem;
        break;
      }
    }
    _notify();
  }

  void deregister(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _notify();
  }

  void terminate(String id) {
    final taskIndex = _tasks.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      if (task.onCancel != null) {
        try {
          task.onCancel!();
        } catch (e) {
          debugPrint('Error terminating task $id: $e');
        }
      }
      _tasks.removeAt(taskIndex);
      _notify();
    }
  }

  void terminateAll() {
    for (var task in List.from(_tasks)) {
      if (task.onCancel != null) {
        try {
          task.onCancel!();
        } catch (_) {}
      }
    }
    _tasks.clear();
    _notify();
  }

  void _notify() {
    tasksNotifier.value = List.from(_tasks);
  }
}
