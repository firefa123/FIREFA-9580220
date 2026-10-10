import 'package:flutter/material.dart';

import '../../controllers/checkout_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/pos_controller.dart';
import '../../controllers/receipt_controller.dart';
import '../../models/payment_model.dart';
import '../../models/receipt_model.dart';
import '../../models/transaction_model.dart';
import '../../repositories/in_memory_order_repository.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final posController = PosController();
  final checkoutController = CheckoutController();
  final paymentController = PaymentController();
  final receiptController = ReceiptController();
  final orderRepository = InMemoryOrderRepository();

  final products = const [
    {'name': 'Nasi Goreng', 'price': 20000},
    {'name': 'Burger', 'price': 25000},
    {'name': 'Coffee', 'price': 15000},
    {'name': 'Tea', 'price': 10000},
  ];

  TransactionModel? transaction;
  PaymentModel? payment;
  ReceiptModel? receipt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS')),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        posController.addItem(
                          product['name'] as String,
                          product['price'] as int,
                        );
                        _resetPaymentState();
                      });
                    },
                    child: Center(
                      child: Text(
                        '${product['name']}\nRp ${product['price']}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Cart',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: posController.cart.isEmpty
                          ? const Center(child: Text('Cart masih kosong'))
                          : ListView(
                              children: posController.cart
                                  .map(
                                    (item) => ListTile(
                                      title: Text(item.name),
                                      subtitle: Text('Qty ${item.quantity}'),
                                      trailing: Text('Rp ${item.subtotal}'),
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total: Rp ${posController.total}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (transaction == null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              posController.cart.isEmpty ? null : _checkout,
                          child: const Text('Checkout'),
                        ),
                      )
                    else if (payment == null)
                      _paymentSelector()
                    else if (receipt == null)
                      _paymentStatus()
                    else
                      _receiptSummary(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Transaksi: ${transaction!.id}'),
        const SizedBox(height: 8),
        const Text('Pilih metode pembayaran'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PaymentMethod.values
              .map(
                (method) => OutlinedButton(
                  onPressed: () => _createPayment(method),
                  child: Text(_paymentMethodLabel(method)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _paymentStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Metode: ${_paymentMethodLabel(payment!.method)}'),
        Text('Status: ${payment!.status.name}'),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _markPaymentPaid,
          child: const Text('Tandai Lunas'),
        ),
      ],
    );
  }

  Widget _receiptSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pembayaran berhasil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Transaction: ${receipt!.transactionId}'),
        Text('Payment: ${receipt!.paymentId}'),
        Text('Metode: ${receipt!.paymentMethod}'),
        Text('Total: Rp ${receipt!.totalAmount.toStringAsFixed(0)}'),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: _newTransaction,
          child: const Text('Transaksi Baru'),
        ),
      ],
    );
  }

  Future<void> _checkout() async {
    final created = checkoutController.checkout(posController.cart);
    if (created == null) {
      return;
    }

    await orderRepository.saveTransaction(created);

    if (!mounted) {
      return;
    }

    setState(() {
      transaction = created;
      payment = null;
      receipt = null;
    });
  }

  Future<void> _createPayment(PaymentMethod method) async {
    final currentTransaction = transaction;
    if (currentTransaction == null) {
      return;
    }

    final createdPayment = paymentController.createPayment(
      transaction: currentTransaction,
      method: method,
    );

    await orderRepository.savePayment(createdPayment);

    if (!mounted) {
      return;
    }

    setState(() {
      payment = createdPayment;
      receipt = null;
    });
  }

  Future<void> _markPaymentPaid() async {
    final currentPayment = payment;
    final currentTransaction = transaction;
    if (currentPayment == null || currentTransaction == null) {
      return;
    }

    final paidPayment = paymentController.markPaid(currentPayment);
    final paidTransaction = checkoutController.markPaid(currentTransaction);
    final generatedReceipt = receiptController.generate(
      transaction: paidTransaction,
      payment: paidPayment,
    );

    final completedTransaction = checkoutController.complete(paidTransaction);

    await orderRepository.savePayment(paidPayment);
    await orderRepository.saveTransaction(completedTransaction);

    if (!mounted) {
      return;
    }

    setState(() {
      payment = paidPayment;
      transaction = completedTransaction;
      receipt = generatedReceipt;
    });
  }

  void _newTransaction() {
    setState(() {
      posController.clearCart();
      transaction = null;
      payment = null;
      receipt = null;
    });
  }

  void _resetPaymentState() {
    transaction = null;
    payment = null;
    receipt = null;
  }

  String _paymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.qris:
        return 'QRIS';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }
}
