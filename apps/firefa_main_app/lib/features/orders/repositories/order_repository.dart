import '../models/payment_model.dart';
import '../models/transaction_model.dart';

abstract class OrderRepository {
  Future<void> saveTransaction(TransactionModel transaction);

  Future<void> savePayment(PaymentModel payment);

  Future<TransactionModel?> getTransaction(String transactionId);

  Future<List<TransactionModel>> getPendingSyncTransactions();

  Future<void> markTransactionSynced(String transactionId);
}
