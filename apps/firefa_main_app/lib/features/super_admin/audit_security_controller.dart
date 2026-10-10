import 'audit_security_model.dart';

class AuditSecurityController {
  final List<AuditSecurityModel> logs = [];

  void addLog(AuditSecurityModel log) {
    logs.add(log);
  }

  List<AuditSecurityModel> get allLogs => logs;
}
