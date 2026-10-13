class StaffAttendanceModel {
  final String staffId;
  final DateTime checkIn;
  final DateTime? checkOut;

  const StaffAttendanceModel({
    required this.staffId,
    required this.checkIn,
    this.checkOut,
  });

  bool get isWorking => checkOut == null;
}
