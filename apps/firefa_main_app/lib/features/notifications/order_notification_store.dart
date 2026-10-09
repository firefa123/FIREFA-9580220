import 'order_notification_model.dart';

class OrderNotificationStore {
  final List<OrderNotification> notifications = [];

  void add(OrderNotification notification) {
    notifications.add(notification);
  }

  void clear() {
    notifications.clear();
  }

  int get unreadCount => notifications.length;
}
