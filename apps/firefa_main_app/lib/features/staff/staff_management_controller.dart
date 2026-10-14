import 'staff_user_model.dart';

/// Manages staff identities in memory with basic input and uniqueness checks.
class StaffManagementController {
  final List<StaffUserModel> _staff = [];

  List<StaffUserModel> get staff => List.unmodifiable(_staff);

  void addStaff(StaffUserModel user) {
    final normalized = _normalize(user);
    if (_staff.any((existing) => existing.id == normalized.id)) {
      throw StateError('ID staf sudah terdaftar.');
    }
    _staff.add(normalized);
  }

  bool updateStaff(String currentId, StaffUserModel updatedUser) {
    final normalizedCurrentId = currentId.trim();
    final index = _staff.indexWhere(
      (existing) => existing.id == normalizedCurrentId,
    );
    if (index < 0) return false;

    final normalized = _normalize(updatedUser);
    if (_staff.any(
      (existing) => existing.id == normalized.id &&
          existing.id != normalizedCurrentId,
    )) {
      throw StateError('ID staf sudah digunakan.');
    }

    _staff[index] = normalized;
    return true;
  }

  bool removeStaff(String id) {
    final normalizedId = id.trim();
    final index = _staff.indexWhere((user) => user.id == normalizedId);
    if (index < 0) return false;
    _staff.removeAt(index);
    return true;
  }

  StaffUserModel? findById(String id) {
    final normalizedId = id.trim();
    for (final user in _staff) {
      if (user.id == normalizedId) return user;
    }
    return null;
  }

  List<StaffUserModel> search(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return staff;
    return List.unmodifiable(_staff.where((user) =>
        user.name.toLowerCase().contains(normalizedQuery) ||
        user.id.toLowerCase().contains(normalizedQuery) ||
        user.role.toLowerCase().contains(normalizedQuery)));
  }

  StaffUserModel _normalize(StaffUserModel user) {
    final id = user.id.trim();
    final name = user.name.trim();
    final role = user.role.trim();
    if (id.isEmpty || id.length > 80) {
      throw ArgumentError.value(user.id, 'id', 'ID staf tidak valid.');
    }
    if (name.isEmpty || name.length > 120) {
      throw ArgumentError.value(user.name, 'name', 'Nama staf tidak valid.');
    }
    if (role.isEmpty || role.length > 80) {
      throw ArgumentError.value(user.role, 'role', 'Role staf tidak valid.');
    }
    return StaffUserModel(id: id, name: name, role: role);
  }
}
