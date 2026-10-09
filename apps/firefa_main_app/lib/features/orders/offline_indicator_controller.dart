import 'offline_status.dart';

class OfflineIndicatorController {
  OfflineStatus _status = const OfflineStatus(isOnline: true);

  OfflineStatus get status => _status;

  void update(bool online) {
    _status = OfflineStatus(isOnline: online);
  }
}
