import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/staff/staff_attendance_controller.dart';

void main() {
  group('StaffAttendanceController', () {
    test('checks staff in and out while maintaining active count', () {
      final controller = StaffAttendanceController();
      final checkInAt = DateTime(2026, 10, 14, 8);
      final checkOutAt = DateTime(2026, 10, 14, 17);

      controller.checkIn(' STAFF-1 ', at: checkInAt);

      expect(controller.activeStaffCount, 1);
      expect(controller.records.single.staffId, 'STAFF-1');
      expect(controller.records.single.isWorking, isTrue);

      expect(
        controller.checkOut('STAFF-1', at: checkOutAt),
        isTrue,
      );
      expect(controller.activeStaffCount, 0);
      expect(controller.records.single.checkOut, checkOutAt);
      expect(controller.records.single.isWorking, isFalse);
    });

    test('rejects duplicate active check-in for the same staff member', () {
      final controller = StaffAttendanceController();
      controller.checkIn('STAFF-1');

      expect(
        () => controller.checkIn('STAFF-1'),
        throwsStateError,
      );
      expect(controller.records, hasLength(1));
    });

    test('allows a new attendance session after check-out', () {
      final controller = StaffAttendanceController();
      controller.checkIn('STAFF-1', at: DateTime(2026, 10, 14, 8));
      controller.checkOut('STAFF-1', at: DateTime(2026, 10, 14, 16));
      controller.checkIn('STAFF-1', at: DateTime(2026, 10, 15, 8));

      expect(controller.recordsForStaff('STAFF-1'), hasLength(2));
      expect(controller.activeStaffCount, 1);
    });

    test('returns false when checking out staff without active attendance', () {
      final controller = StaffAttendanceController();

      expect(controller.checkOut('STAFF-1'), isFalse);
      expect(controller.activeStaffCount, 0);
    });

    test('rejects blank IDs and checkout earlier than check-in', () {
      final controller = StaffAttendanceController();

      expect(() => controller.checkIn('  '), throwsArgumentError);
      controller.checkIn('STAFF-1', at: DateTime(2026, 10, 14, 9));
      expect(
        () => controller.checkOut(
          'STAFF-1',
          at: DateTime(2026, 10, 14, 8),
        ),
        throwsArgumentError,
      );
      expect(controller.activeStaffCount, 1);
    });

    test('exposes attendance records as an unmodifiable list', () {
      final controller = StaffAttendanceController();
      controller.checkIn('STAFF-1');

      expect(
        () => controller.records.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
