import 'global_monitor_summary.dart';

class GlobalMonitorController {
  GlobalMonitorSummary build({
    required int outlets,
    required int activeUsers,
    required int pendingSync,
  }) {
    return GlobalMonitorSummary(
      outlets: outlets,
      activeUsers: activeUsers,
      pendingSync: pendingSync,
    );
  }
}
