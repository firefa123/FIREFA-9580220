import 'dart:async';

class ConnectivityMonitor {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Stream<bool> get statusStream => _controller.stream;

  void updateStatus(bool online) {
    if (!_controller.isClosed) {
      _controller.add(online);
    }
  }

  void dispose() {
    _controller.close();
  }
}
