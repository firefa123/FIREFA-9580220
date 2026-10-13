import 'staff_activity_log_model.dart';

class StaffActivityLogController {
  final List<StaffActivityLog> _logs = [];

  List<StaffActivityLog> get logs => List.unmodifiable(_logs);

  void addLog(StaffActivityLog log) {
    _logs.add(log);
  }
}
