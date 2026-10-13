import 'staff_attendance_model.dart';

class StaffAttendanceController {
  final List<StaffAttendanceModel> _records = [];

  List<StaffAttendanceModel> get records => List.unmodifiable(_records);

  void checkIn(String staffId) {
    _records.add(
      StaffAttendanceModel(
        staffId: staffId,
        checkIn: DateTime.now(),
      ),
    );
  }

  int get activeStaffCount =>
      _records.where((record) => record.isWorking).length;
}
