import '../../core/storage/local_storage.dart';
import 'offline_order_model.dart';

class OfflineOrderQueue {
  static const String key = 'firefa_offline_orders';

  Future<List<OfflineOrder>> getOrders() async {
    final data = await LocalStorage.read(key);

    if (data == null) return [];

    return (data as List)
        .map((e) => OfflineOrder.fromJson(e))
        .toList();
  }

  Future<List<OfflineOrder>> getPendingOrders() async {
    return getOrders();
  }

  Future<void> add(OfflineOrder order) async {
    final orders = await getOrders();

    orders.add(order);

    await LocalStorage.save(
      key,
      orders.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> remove(String orderId) async {
    final orders = await getOrders();

    orders.removeWhere(
      (e) => e.orderId == orderId,
    );

    await LocalStorage.save(
      key,
      orders.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> clear() async {
    await LocalStorage.remove(key);
  }
}
