class SubscriptionManagementModel {
  final String tenantId;
  final String plan;
  final int outletLimit;

  const SubscriptionManagementModel({
    required this.tenantId,
    required this.plan,
    required this.outletLimit,
  });
}
