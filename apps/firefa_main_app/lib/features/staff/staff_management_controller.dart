import 'staff_user_model.dart';

class StaffManagementController {
  final List<StaffUserModel> _staff = [];

  List<StaffUserModel> get staff => List.unmodifiable(_staff);

  void addStaff(StaffUserModel user) {
    _staff.add(user);
  }
}
