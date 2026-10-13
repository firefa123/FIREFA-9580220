import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/modules/sync_adapter.dart';
import 'package:firefa_main_app/features/modules/sync_engine.dart';

void main() {
  const engine = FirefaSyncEngine();

  test('retry delay is monotonic and capped for large attempt counts', () {
    var previous = Duration.zero;
    for (var attempts = 0; attempts <= 20; attempts++) {
      final delay = engine.retryDelay(attempts);
      expect(delay >= previous, isTrue, reason: 'attempt $attempts');
      expect(delay <= const Duration(minutes: 5), isTrue);
      previous = delay;
    }
    expect(engine.retryDelay(20), const Duration(seconds: 256));
  });

  test('sync envelope deeply freezes nested snapshot payloads', () {
    final mutableSnapshot = <String, dynamic>{
      'id': 'immutable-envelope',
      'items': <dynamic>[
        <String, dynamic>{'name': 'Coffee', 'quantity': 1},
      ],
    };
    final envelope = FirefaSyncEnvelope(
      eventId: 'evt-immutable',
      outletId: 'outlet-immutable',
      orderId: 'immutable-envelope',
      eventType: 'order.created',
      createdAt: DateTime.utc(2026, 10, 13),
      orderSnapshot: mutableSnapshot,
    );

    mutableSnapshot['id'] = 'changed-after-construction';
    (mutableSnapshot['items'] as List).add({'name': 'Injected'});

    expect(envelope.orderSnapshot['id'], 'immutable-envelope');
    final items = envelope.orderSnapshot['items'] as List;
    expect(items, hasLength(1));
    expect(
      () => items.add({'name': 'Injected'}),
      throwsUnsupportedError,
    );
    expect(
      () => (items.single as Map)['quantity'] = 99,
      throwsUnsupportedError,
    );
  });

  test('acknowledgement requires exact event identity and nonblank reference', () {
    final event = FirefaSyncEnvelope(
      eventId: 'evt-123',
      outletId: 'outlet-1',
      orderId: 'order-1',
      eventType: 'order.created',
      createdAt: DateTime.utc(2026, 10, 13),
      orderSnapshot: {},
    );

    expect(
      engine.isValidAcknowledgement(
        event,
        const FirefaSyncReceipt(
          eventId: 'evt-123',
          outcome: FirefaSyncOutcome.acknowledged,
          serverReference: 'receipt-1',
        ),
      ),
      isTrue,
    );
    for (final reference in <String?>[null, '', '   ']) {
      expect(
        engine.isValidAcknowledgement(
          event,
          FirefaSyncReceipt(
            eventId: 'evt-123',
            outcome: FirefaSyncOutcome.acknowledged,
            serverReference: reference,
          ),
        ),
        isFalse,
      );
    }
    expect(
      engine.isValidAcknowledgement(
        event,
        const FirefaSyncReceipt(
          eventId: 'evt-other',
          outcome: FirefaSyncOutcome.acknowledged,
          serverReference: 'receipt-1',
        ),
      ),
      isFalse,
    );
  });
}
