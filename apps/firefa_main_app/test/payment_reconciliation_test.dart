import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/payment_reconciliation.dart';

void main() {
  const reconciliation = FirefaPaymentReconciliation();

  test('matches equal amounts when optional statuses are omitted', () {
    final result = reconciliation.compare(
      paymentId: 'payment-1',
      localAmount: 125000,
      serverAmount: 125000,
      serverExists: true,
      duplicate: false,
    );

    expect(result.status, FirefaPaymentMatchStatus.matched);
    expect(result.checkedAt.isUtc, isTrue);
  });

  test('detects payment status mismatch even when amounts match', () {
    final result = reconciliation.compare(
      paymentId: 'payment-2',
      localAmount: 125000,
      serverAmount: 125000,
      serverExists: true,
      duplicate: false,
      localStatus: 'paid',
      serverStatus: 'pending',
    );

    expect(result.status, FirefaPaymentMatchStatus.statusMismatch);
  });

  test('detects amount mismatch when statuses match', () {
    final result = reconciliation.compare(
      paymentId: 'payment-3',
      localAmount: 125000,
      serverAmount: 120000,
      serverExists: true,
      duplicate: false,
      localStatus: 'paid',
      serverStatus: 'paid',
    );

    expect(result.status, FirefaPaymentMatchStatus.amountMismatch);
  });

  test('duplicate and missing server records take precedence', () {
    final duplicate = reconciliation.compare(
      paymentId: 'payment-4',
      localAmount: 100,
      serverAmount: 100,
      serverExists: true,
      duplicate: true,
      localStatus: 'paid',
      serverStatus: 'pending',
    );
    expect(duplicate.status, FirefaPaymentMatchStatus.duplicateDetected);

    final missing = reconciliation.compare(
      paymentId: 'payment-5',
      localAmount: 100,
      serverAmount: 100,
      serverExists: false,
      duplicate: false,
    );
    expect(missing.status, FirefaPaymentMatchStatus.missingOnServer);
  });

  test('rejects blank payment IDs and invalid monetary values', () {
    expect(
      () => reconciliation.compare(
        paymentId: '  ',
        localAmount: 1,
        serverAmount: 1,
        serverExists: true,
        duplicate: false,
      ),
      throwsArgumentError,
    );

    for (final amount in <double>[double.nan, double.infinity, -1]) {
      expect(
        () => reconciliation.compare(
          paymentId: 'payment-invalid',
          localAmount: amount,
          serverAmount: 1,
          serverExists: true,
          duplicate: false,
        ),
        throwsArgumentError,
      );
    }
  });
}
