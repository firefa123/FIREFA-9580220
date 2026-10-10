class OfflineStatus {
  final bool isOnline;

  const OfflineStatus({
    required this.isOnline,
  });

  bool get isOffline => !isOnline;
}
