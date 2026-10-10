import 'offline_status.dart';

class OrderStatusSummary {
  final OfflineStatus status;

  const OrderStatusSummary({
    required this.status,
  });

  String get label {
    if (status.isOffline) {
      return 'Offline - Menunggu Sinkronisasi';
    }

    return 'Online - Siap Sinkron';
  }
}
