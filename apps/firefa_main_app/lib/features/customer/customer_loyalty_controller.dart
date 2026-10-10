import 'customer_loyalty_model.dart';

class CustomerLoyaltyController {
  CustomerLoyaltyModel addPoints({
    required CustomerLoyaltyModel current,
    required int points,
  }) {
    return CustomerLoyaltyModel(
      customerId: current.customerId,
      points: current.points + points,
      rewardCount: current.rewardCount,
    );
  }
}
