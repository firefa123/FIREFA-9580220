class CustomerLoyaltyModel {
  final String customerId;
  final int points;
  final int rewardCount;

  const CustomerLoyaltyModel({
    required this.customerId,
    required this.points,
    required this.rewardCount,
  });
}
