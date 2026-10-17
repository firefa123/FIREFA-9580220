import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/payment_reconciliation.dart';

void main() {
  const reconciliation = FirefaPaymentReconciliation();

  test('matches equal amounts for an existing unique payment', () {
    final result = reconciliation.compare(
      paymentId: 'payment-1',
      localAmount: 125000,
      serverAmount: 125000,
      serverExists: true,
      duplicate: false,
    );

    expect(result.status, FirefaPaymentMatchStatus.matched);
    expect(result.paymentId, 'payment-1');
    expect(result.checkedAt.isUtc, isTrue);
  });

  test('detects amount mismatch for an existing payment', () {
    final result = reconciliation.compare(
      paymentId: 'payment-2',
      localAmount: 125000,
      serverAmount: 120000,
      serverExists: true,
      duplicate: false,
    );

    expect(result.status, FirefaPaymentMatchStatus.amountMismatch);
    expect(result.localAmount, 125000);
    expect(result.serverAmount, 120000);
  });

  test('duplicate and missing server records are reported distinctly', () {
    final duplicate = reconciliation.compare(
      paymentId: 'payment-3',
      localAmount: 100,
      serverAmount: 100,
      serverExists: true,
      duplicate: true,
    );
    expect(duplicate.status, FirefaPaymentMatchStatus.duplicateDetected);

    final missing = reconciliation.compare(
      paymentId: 'payment-4',
      localAmount: 100,
      serverAmount: 100,
      serverExists: false,
      duplicate: false,
    );
    expect(missing.status, FirefaPaymentMatchStatus.missingOnServer);
  });
}
