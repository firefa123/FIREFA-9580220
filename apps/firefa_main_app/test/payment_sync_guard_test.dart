import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/payment_sync_guard.dart';

void main() {
  const guard = FirefaPaymentSyncGuard();

  test('only queued and failed payments can retry', () {
    expect(guard.canRetry(FirefaPaymentSyncStatus.queued), isTrue);
    expect(guard.canRetry(FirefaPaymentSyncStatus.failed), isTrue);
    expect(guard.canRetry(FirefaPaymentSyncStatus.localPending), isFalse);
    expect(guard.canRetry(FirefaPaymentSyncStatus.syncing), isFalse);
    expect(guard.canRetry(FirefaPaymentSyncStatus.completed), isFalse);
    expect(guard.canRetry(FirefaPaymentSyncStatus.conflict), isFalse);
  });

  test('only conflict status requires manual review', () {
    expect(guard.requiresReview(FirefaPaymentSyncStatus.conflict), isTrue);
    expect(guard.requiresReview(FirefaPaymentSyncStatus.queued), isFalse);
    expect(guard.requiresReview(FirefaPaymentSyncStatus.failed), isFalse);
    expect(guard.requiresReview(FirefaPaymentSyncStatus.completed), isFalse);
  });

  test('processed payment IDs are detected to prevent duplicate submission', () {
    final processed = <String>{'payment-1', 'payment-2'};
    expect(
      guard.preventDuplicateSubmission(
        paymentId: 'payment-1',
        processedPaymentIds: processed,
      ),
      isTrue,
    );
    expect(
      guard.preventDuplicateSubmission(
        paymentId: 'payment-new',
        processedPaymentIds: processed,
      ),
      isFalse,
    );
  });
}
