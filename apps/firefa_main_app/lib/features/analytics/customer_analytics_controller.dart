import '../customer/customer_loyalty_model.dart';
import 'customer_analytics_model.dart';

/// Builds customer metrics from explicit customer loyalty records and order
/// counts. Order history is supplied separately because legacy orders do not
/// currently carry a customer ID.
class CustomerAnalyticsController {
  CustomerAnalyticsController({
    List<CustomerLoyaltyModel> loyaltyRecords = const [],
    Map<String, int> completedOrdersByCustomer = const {},
  })  : _loyaltyRecords = List.unmodifiable(loyaltyRecords),
        _completedOrdersByCustomer = Map.unmodifiable(
          completedOrdersByCustomer,
        ) {
    if (_completedOrdersByCustomer.values.any((count) => count < 0)) {
      throw ArgumentError.value(
        completedOrdersByCustomer,
        'completedOrdersByCustomer',
        'Jumlah pesanan tidak boleh negatif.',
      );
    }
  }

  final List<CustomerLoyaltyModel> _loyaltyRecords;
  final Map<String, int> _completedOrdersByCustomer;

  CustomerAnalyticsModel getSummary() {
    final customerIds = <String>{
      for (final record in _loyaltyRecords)
        if (record.customerId.trim().isNotEmpty) record.customerId,
      for (final entry in _completedOrdersByCustomer.entries)
        if (entry.key.trim().isNotEmpty && entry.value > 0) entry.key,
    };

    final repeatCustomers = customerIds
        .where((customerId) => (_completedOrdersByCustomer[customerId] ?? 0) > 1)
        .length;
    final loyaltyPoints = _loyaltyRecords.fold<int>(
      0,
      (total, record) => total + record.points,
    );

    return CustomerAnalyticsModel(
      totalCustomers: customerIds.length,
      repeatCustomers: repeatCustomers,
      loyaltyPointsIssued: loyaltyPoints,
    );
  }
}
