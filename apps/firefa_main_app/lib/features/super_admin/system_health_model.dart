class SystemHealthModel {
  final int activeOutlets;
  final int onlineUsers;
  final int pendingSync;
  final bool healthy;

  const SystemHealthModel({
    required this.activeOutlets,
    required this.onlineUsers,
    required this.pendingSync,
    required this.healthy,
  });
}
