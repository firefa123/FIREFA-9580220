class GlobalUserManagementController {
  final List<String> activeUsers = [];

  void addUser(String userId) {
    activeUsers.add(userId);
  }

  List<String> getUsers() => List.unmodifiable(activeUsers);
}
