import 'staff_attendance_model.dart';

/// In-memory attendance workflow. Persistence can be added through a store
/// without changing the attendance rules exposed here.
class StaffAttendanceController {
  final List<StaffAttendanceModel> _records = [];

  List<StaffAttendanceModel> get records => List.unmodifiable(_records);

  void checkIn(String staffId, {DateTime? at}) {
    final normalizedId = staffId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(staffId, 'staffId', 'ID staf wajib diisi.');
    }
    if (_records.any(
      (record) => record.staffId == normalizedId && record.isWorking,
    )) {
      throw StateError('Staf sudah check-in dan belum check-out.');
    }

    _records.add(
      StaffAttendanceModel(
        staffId: normalizedId,
        checkIn: at ?? DateTime.now(),
      ),
    );
  }

  /// Closes the latest active attendance record for a staff member.
  /// Returns false when the staff member has no active attendance.
  bool checkOut(String staffId, {DateTime? at}) {
    final normalizedId = staffId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(staffId, 'staffId', 'ID staf wajib diisi.');
    }

    final index = _records.lastIndexWhere(
      (record) => record.staffId == normalizedId && record.isWorking,
    );
    if (index < 0) return false;

    final record = _records[index];
    final checkedOutAt = at ?? DateTime.now();
    if (checkedOutAt.isBefore(record.checkIn)) {
      throw ArgumentError.value(
        checkedOutAt,
        'at',
        'Waktu check-out tidak boleh sebelum check-in.',
      );
    }

    _records[index] = StaffAttendanceModel(
      staffId: record.staffId,
      checkIn: record.checkIn,
      checkOut: checkedOutAt,
    );
    return true;
  }

  int get activeStaffCount =>
      _records.where((record) => record.isWorking).length;

  List<StaffAttendanceModel> recordsForStaff(String staffId) {
    final normalizedId = staffId.trim();
    return List.unmodifiable(
      _records.where((record) => record.staffId == normalizedId),
    );
  }
}
