import 'staff_activity_log_model.dart';

/// In-memory audit trail for staff actions.
class StaffActivityLogController {
  final List<StaffActivityLog> _logs = [];

  /// Newest activity first, returned as a read-only collection.
  List<StaffActivityLog> get logs =>
      List.unmodifiable(_logs.reversed.toList(growable: false));

  void addLog(StaffActivityLog log) {
    final staffId = log.staffId.trim();
    final action = log.action.trim();
    if (staffId.isEmpty || staffId.length > 80) {
      throw ArgumentError.value(log.staffId, 'staffId', 'ID staf tidak valid.');
    }
    if (action.isEmpty || action.length > 240) {
      throw ArgumentError.value(log.action, 'action', 'Deskripsi aktivitas tidak valid.');
    }

    _logs.add(StaffActivityLog(
      staffId: staffId,
      action: action,
      createdAt: log.createdAt,
    ));
  }

  List<StaffActivityLog> logsForStaff(String staffId) {
    final normalizedId = staffId.trim();
    return List.unmodifiable(
      _logs.reversed.where((log) => log.staffId == normalizedId),
    );
  }

  List<StaffActivityLog> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return logs;
    return List.unmodifiable(_logs.reversed.where((log) =>
        log.staffId.toLowerCase().contains(normalizedQuery) ||
        log.action.toLowerCase().contains(normalizedQuery)));
  }

  List<StaffActivityLog> logsBetween(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      throw ArgumentError.value(end, 'end', 'Waktu akhir sebelum waktu awal.');
    }
    return List.unmodifiable(_logs.reversed.where((log) =>
        !log.createdAt.isBefore(start) && !log.createdAt.isAfter(end)));
  }

  int get totalActivities => _logs.length;
}
