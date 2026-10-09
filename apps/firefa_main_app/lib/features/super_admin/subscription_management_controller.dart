import 'subscription_management_model.dart';

class SubscriptionManagementController {
  final List<SubscriptionManagementModel> subscriptions = [];

  void addSubscription(SubscriptionManagementModel subscription) {
    subscriptions.add(subscription);
  }
}
