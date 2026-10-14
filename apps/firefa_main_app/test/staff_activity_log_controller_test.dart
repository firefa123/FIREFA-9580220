import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/staff/staff_activity_log_controller.dart';
import 'package:firefa_main_app/features/staff/staff_activity_log_model.dart';

void main() {
  group('StaffActivityLogController', () {
    final firstAt = DateTime(2026, 10, 14, 9);
    final secondAt = DateTime(2026, 10, 14, 10);
    final thirdAt = DateTime(2026, 10, 15, 11);

    StaffActivityLog log(String staffId, String action, DateTime at) =>
        StaffActivityLog(staffId: staffId, action: action, createdAt: at);

    test('normalizes entries and lists newest activities first', () {
      final controller = StaffActivityLogController()
        ..addLog(log(' STAFF-1 ', ' Login ', firstAt))
        ..addLog(log('STAFF-2', 'Updated menu', secondAt));

      expect(controller.totalActivities, 2);
      expect(controller.logs.first.staffId, 'STAFF-2');
      expect(controller.logs.last.action, 'Login');
    });

    test('filters logs by staff ID', () {
      final controller = StaffActivityLogController()
        ..addLog(log('STAFF-1', 'Login', firstAt))
        ..addLog(log('STAFF-2', 'Updated menu', secondAt))
        ..addLog(log('STAFF-1', 'Logout', thirdAt));

      expect(controller.logsForStaff(' STAFF-1 '), hasLength(2));
      expect(controller.logsForStaff('STAFF-1').first.action, 'Logout');
      expect(controller.logsForStaff('missing'), isEmpty);
    });

    test('searches staff IDs and action descriptions case-insensitively', () {
      final controller = StaffActivityLogController()
        ..addLog(log('STAFF-1', 'Opened REPORTS', firstAt))
        ..addLog(log('STAFF-2', 'Updated menu', secondAt));

      expect(controller.search('reports'), hasLength(1));
      expect(controller.search('staff-2'), hasLength(1));
      expect(controller.search(''), hasLength(2));
      expect(controller.search('not-found'), isEmpty);
    });

    test('filters logs within inclusive date boundaries', () {
      final controller = StaffActivityLogController()
        ..addLog(log('STAFF-1', 'Start', firstAt))
        ..addLog(log('STAFF-1', 'Middle', secondAt))
        ..addLog(log('STAFF-1', 'Next day', thirdAt));

      expect(
        controller.logsBetween(firstAt, secondAt).map((entry) => entry.action),
        ['Updated', 'Middle'],
      );
    });

    test('rejects invalid time ranges and invalid log fields', () {
      final controller = StaffActivityLogController();

      expect(
        () => controller.logsBetween(secondAt, firstAt),
        throwsArgumentError,
      );
      expect(
        () => controller.addLog(log(' ', 'Login', firstAt)),
        throwsArgumentError,
      );
      expect(
        () => controller.addLog(log('STAFF-1', ' ', firstAt)),
        throwsArgumentError,
      );
      expect(controller.totalActivities, 0);
    });

    test('returns an unmodifiable log list', () {
      final controller = StaffActivityLogController()
        ..addLog(log('STAFF-1', 'Login', firstAt));

      expect(() => controller.logs.clear(), throwsUnsupportedError);
    });
  });
}
