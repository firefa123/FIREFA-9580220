import 'system_health_model.dart';

class SystemMonitorController {
  SystemHealthModel state = const SystemHealthModel(
    activeOutlets: 0,
    onlineUsers: 0,
    pendingSync: 0,
    healthy: true,
  );

  void update(SystemHealthModel value) {
    state = value;
  }
}
