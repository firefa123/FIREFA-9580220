import 'package:flutter/material.dart';

import '../../controllers/checkout_controller.dart';
import '../../controllers/payment_controller.dart';
import '../../controllers/pos_controller.dart';
import '../../controllers/receipt_controller.dart';
import '../../models/cart_item_model.dart';
import '../../models/payment_model.dart';
import '../../models/receipt_model.dart';
import '../../models/transaction_model.dart';
import '../../repositories/local_order_repository.dart';

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
  final orderRepository = LocalOrderRepository();

  final products = const [
    {'name': 'Nasi Goreng', 'price': 20000},
    {'name': 'Burger', 'price': 25000},
    {'name': 'Coffee', 'price': 15000},
    {'name': 'Tea', 'price': 10000},
  ];

  TransactionModel? transaction;
  PaymentModel? payment;
  ReceiptModel? receipt;
  List<TransactionModel> recentTransactions = const [];
  bool _loadingHistory = false;
  bool _checkoutInProgress = false;
  bool _paymentInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

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
                    onTap: transaction != null
                        ? null
                        : () {
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
                    _historySection(),
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
                          onPressed: posController.cart.isEmpty ||
                                  _checkoutInProgress
                              ? null
                              : _checkout,
                          child: _checkoutInProgress
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Checkout'),
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
        OutlinedButton(
          onPressed: _cancelTransaction,
          child: const Text('Batalkan Transaksi'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PaymentMethod.values
              .map(
                (method) => OutlinedButton(
                  onPressed: _paymentInProgress
                      ? null
                      : () => _createPayment(method),
                  child: Text(_paymentMethodLabel(method)),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _paymentStatus() {
    final currentTransaction = transaction!;
    if (currentTransaction.status == TransactionStatus.cancelled ||
        currentTransaction.status == TransactionStatus.completed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Status transaksi: ${currentTransaction.status.name}'),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: _newTransaction,
            child: const Text('Transaksi Baru'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Metode: ${_paymentMethodLabel(payment!.method)}'),
        Text('Status: ${payment!.status.name}'),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: payment!.status == PaymentStatus.pending &&
                  !_paymentInProgress
              ? _markPaymentPaid
              : null,
          child: _paymentInProgress
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Tandai Lunas'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: payment!.status == PaymentStatus.pending
              ? _cancelTransaction
              : null,
          child: const Text('Batalkan Transaksi'),
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

  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Riwayat Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (_loadingHistory)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                tooltip: 'Muat ulang riwayat',
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh, size: 18),
              ),
          ],
        ),
        if (!_loadingHistory && recentTransactions.isEmpty)
          const Text('Belum ada transaksi tersimpan.')
        else
          ...recentTransactions.take(4).map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.status.name} · Rp ${item.totalAmount.toStringAsFixed(0)}',
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _resumeTransaction(item),
                ),
              ),
      ],
    );
  }

  Future<void> _loadHistory() async {
    if (_loadingHistory) return;
    setState(() => _loadingHistory = true);
    try {
      final transactions = await orderRepository.getTransactions();
      if (!mounted) return;
      setState(() {
        recentTransactions = transactions;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Riwayat transaksi gagal dimuat.')),
      );
    }
  }

  Future<void> _resumeTransaction(TransactionModel selected) async {
    final selectedPayment =
        await orderRepository.getPaymentForTransaction(selected.id);
    ReceiptModel? restoredReceipt;
    if (selectedPayment?.status == PaymentStatus.paid &&
        (selected.status == TransactionStatus.paid ||
            selected.status == TransactionStatus.completed)) {
      restoredReceipt = receiptController.generate(
        transaction: selected,
        payment: selectedPayment!,
      );
    }
    if (!mounted) return;
    setState(() {
      transaction = selected;
      payment = selectedPayment;
      receipt = restoredReceipt;
      posController.restoreCart(
        selected.itemDetails
            .map(
              (line) => CartItemModel(
                id: line.id,
                name: line.name,
                price: line.unitPrice,
                quantity: line.quantity,
              ),
            )
            .toList(growable: false),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transaksi lokal berhasil dibuka kembali.')),
    );
  }

  Future<void> _checkout() async {
    if (_checkoutInProgress || transaction != null) return;
    setState(() => _checkoutInProgress = true);
    try {
      final created = checkoutController.checkout(posController.cart);
      if (created == null) return;

      await orderRepository.saveTransaction(created);
      if (!mounted) return;
      setState(() {
        transaction = created;
        payment = null;
        receipt = null;
        recentTransactions = [created, ...recentTransactions];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checkout gagal disimpan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _checkoutInProgress = false);
    }
  }

  Future<void> _createPayment(PaymentMethod method) async {
    final currentTransaction = transaction;
    if (_paymentInProgress ||
        currentTransaction == null ||
        payment != null ||
        currentTransaction.status != TransactionStatus.awaitingPayment) {
      return;
    }

    setState(() => _paymentInProgress = true);
    try {
      final createdPayment = paymentController.createPayment(
        transaction: currentTransaction,
        method: method,
      );
      await orderRepository.savePayment(createdPayment);
      if (!mounted) return;
      setState(() {
        payment = createdPayment;
        receipt = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran gagal disimpan. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _paymentInProgress = false);
    }
  }

  Future<void> _markPaymentPaid() async {
    final currentPayment = payment;
    final currentTransaction = transaction;
    if (_paymentInProgress ||
        currentPayment == null ||
        currentTransaction == null ||
        currentPayment.status != PaymentStatus.pending ||
        currentTransaction.status != TransactionStatus.awaitingPayment) {
      return;
    }

    setState(() => _paymentInProgress = true);
    try {
      final paidPayment = paymentController.markPaid(currentPayment);
      final paidTransaction = checkoutController.markPaid(currentTransaction);
      if (paidPayment.status != PaymentStatus.paid ||
          paidTransaction.status != TransactionStatus.paid) {
        throw StateError('Transisi pembayaran tidak valid.');
      }
      final completedTransaction = checkoutController.complete(paidTransaction);
      final generatedReceipt = receiptController.generate(
        transaction: completedTransaction,
        payment: paidPayment,
      );

      await orderRepository.savePayment(paidPayment);
      await orderRepository.saveTransaction(paidTransaction);
      await orderRepository.saveTransaction(completedTransaction);
      if (!mounted) return;
      setState(() {
        payment = paidPayment;
        transaction = completedTransaction;
        receipt = generatedReceipt;
        recentTransactions = [
          completedTransaction,
          ...recentTransactions.where((item) => item.id != completedTransaction.id),
        ];
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran belum berhasil disimpan. Periksa riwayat transaksi.')),
      );
    } finally {
      if (mounted) setState(() => _paymentInProgress = false);
    }
  }

  Future<void> _cancelTransaction() async {
    final currentTransaction = transaction;
    final currentPayment = payment;
    if (currentTransaction == null ||
        (currentTransaction.status != TransactionStatus.awaitingPayment &&
            currentTransaction.status != TransactionStatus.pending) ||
        (currentPayment != null &&
            currentPayment.status != PaymentStatus.pending)) {
      return;
    }

    final cancelledTransaction =
        checkoutController.cancel(currentTransaction);
    final failedPayment = currentPayment == null
        ? null
        : paymentController.markFailed(currentPayment);

    if (failedPayment != null) {
      await orderRepository.savePayment(failedPayment);
    }
    await orderRepository.saveTransaction(cancelledTransaction);

    if (!mounted) return;
    setState(() {
      recentTransactions = [
        cancelledTransaction,
        ...recentTransactions.where((item) => item.id != cancelledTransaction.id),
      ];
      transaction = null;
      payment = null;
      receipt = null;
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
