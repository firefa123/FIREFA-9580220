import 'subscription_management_model.dart';

/// In-memory subscription management for Super Admin.
///
/// Subscription plans share the same feature set; the plan's outlet limit is
/// the only capability limit represented by this model. Persistence and
/// tenant-existence checks belong to the backend integration layer.
class SubscriptionManagementController {
  final List<SubscriptionManagementModel> _subscriptions = [];

  List<SubscriptionManagementModel> get subscriptions =>
      List.unmodifiable(_subscriptions);

  void addSubscription(SubscriptionManagementModel subscription) {
    final normalized = _normalize(subscription);
    _validate(normalized);

    if (_subscriptions.any((item) => item.tenantId == normalized.tenantId)) {
      throw ArgumentError.value(
        normalized.tenantId,
        'tenantId',
        'A subscription already exists for this tenant.',
      );
    }

    _subscriptions.add(normalized);
  }

  bool updateSubscription(
    String tenantId,
    SubscriptionManagementModel subscription,
  ) {
    final normalizedTenantId = tenantId.trim();
    final index = _subscriptions.indexWhere(
      (item) => item.tenantId == normalizedTenantId,
    );
    if (index == -1) return false;

    final normalized = _normalize(subscription);
    _validate(normalized);

    final duplicate = _subscriptions.any(
      (item) =>
          item.tenantId == normalized.tenantId &&
          item.tenantId != normalizedTenantId,
    );
    if (duplicate) {
      throw ArgumentError.value(
        normalized.tenantId,
        'tenantId',
        'A subscription already exists for this tenant.',
      );
    }

    _subscriptions[index] = normalized;
    return true;
  }

  SubscriptionManagementModel? findByTenantId(String tenantId) {
    final normalized = tenantId.trim();
    for (final subscription in _subscriptions) {
      if (subscription.tenantId == normalized) return subscription;
    }
    return null;
  }

  bool removeSubscription(String tenantId) {
    final normalized = tenantId.trim();
    final index = _subscriptions.indexWhere(
      (item) => item.tenantId == normalized,
    );
    if (index == -1) return false;
    _subscriptions.removeAt(index);
    return true;
  }

  List<SubscriptionManagementModel> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return subscriptions;
    return List.unmodifiable(_subscriptions.where((item) =>
        item.tenantId.toLowerCase().contains(normalized) ||
        item.plan.toLowerCase().contains(normalized)));
  }

  int get totalSubscriptions => _subscriptions.length;

  SubscriptionManagementModel _normalize(
    SubscriptionManagementModel subscription,
  ) {
    return SubscriptionManagementModel(
      tenantId: subscription.tenantId.trim(),
      plan: subscription.plan.trim(),
      outletLimit: subscription.outletLimit,
    );
  }

  void _validate(SubscriptionManagementModel subscription) {
    if (subscription.tenantId.isEmpty) {
      throw ArgumentError.value(
        subscription.tenantId,
        'tenantId',
        'Tenant ID cannot be empty.',
      );
    }
    if (subscription.plan.isEmpty) {
      throw ArgumentError.value(
        subscription.plan,
        'plan',
        'Plan cannot be empty.',
      );
    }
    if (subscription.outletLimit < 1) {
      throw ArgumentError.value(
        subscription.outletLimit,
        'outletLimit',
        'Outlet limit must be at least 1.',
      );
    }
  }
}
