import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/features/super_admin/subscription_management_controller.dart';
import 'package:firefa_main_app/features/super_admin/subscription_management_model.dart';

SubscriptionManagementModel subscription(
  String tenantId, {
  String plan = 'Starter',
  int outletLimit = 1,
}) {
  return SubscriptionManagementModel(
    tenantId: tenantId,
    plan: plan,
    outletLimit: outletLimit,
  );
}

void main() {
  group('SubscriptionManagementController', () {
    test('adds normalized subscription and finds by tenant ID', () {
      final controller = SubscriptionManagementController();

      controller.addSubscription(
        subscription(' tenant-1 ', plan: ' Growth ', outletLimit: 5),
      );

      expect(controller.totalSubscriptions, 1);
      expect(controller.findByTenantId('tenant-1')?.plan, 'Growth');
      expect(controller.findByTenantId(' tenant-1 ')?.outletLimit, 5);
    });

    test('rejects duplicate tenant subscriptions', () {
      final controller = SubscriptionManagementController();
      controller.addSubscription(subscription('tenant-1'));

      expect(
        () => controller.addSubscription(subscription(' tenant-1 ')),
        throwsArgumentError,
      );
      expect(controller.totalSubscriptions, 1);
    });

    test('rejects blank fields and non-positive outlet limits', () {
      final controller = SubscriptionManagementController();

      expect(() => controller.addSubscription(subscription(' ')),
          throwsArgumentError);
      expect(() => controller.addSubscription(subscription('tenant-1', plan: ' ')),
          throwsArgumentError);
      expect(
        () => controller.addSubscription(
          subscription('tenant-1', outletLimit: 0),
        ),
        throwsArgumentError,
      );
      expect(controller.totalSubscriptions, 0);
    });

    test('updates an existing subscription', () {
      final controller = SubscriptionManagementController();
      controller.addSubscription(subscription('tenant-1'));

      expect(
        controller.updateSubscription(
          'tenant-1',
          subscription('tenant-1', plan: 'Business', outletLimit: 10),
        ),
        isTrue,
      );
      expect(controller.findByTenantId('tenant-1')?.plan, 'Business');
      expect(controller.findByTenantId('tenant-1')?.outletLimit, 10);
    });

    test('returns false when updating an unknown tenant', () {
      final controller = SubscriptionManagementController();

      expect(
        controller.updateSubscription('missing', subscription('missing')),
        isFalse,
      );
    });

    test('rejects update that collides with another tenant', () {
      final controller = SubscriptionManagementController()
        ..addSubscription(subscription('tenant-1'))
        ..addSubscription(subscription('tenant-2'));

      expect(
        () => controller.updateSubscription(
          'tenant-1',
          subscription('tenant-2', plan: 'Business'),
        ),
        throwsArgumentError,
      );
      expect(controller.findByTenantId('tenant-1')?.plan, 'Starter');
    });

    test('searches tenant ID and plan case-insensitively', () {
      final controller = SubscriptionManagementController()
        ..addSubscription(subscription('tenant-alpha', plan: 'Growth'))
        ..addSubscription(subscription('tenant-beta', plan: 'Starter'));

      expect(controller.search('ALPHA').length, 1);
      expect(controller.search('growth').single.tenantId, 'tenant-alpha');
      expect(controller.search(' ').length, 2);
    });

    test('removes subscriptions and reports missing tenant', () {
      final controller = SubscriptionManagementController()
        ..addSubscription(subscription('tenant-1'));

      expect(controller.removeSubscription('tenant-1'), isTrue);
      expect(controller.removeSubscription('tenant-1'), isFalse);
      expect(controller.totalSubscriptions, 0);
    });

    test('exposes an unmodifiable subscription list', () {
      final controller = SubscriptionManagementController()
        ..addSubscription(subscription('tenant-1'));

      expect(
        () => controller.subscriptions.add(subscription('tenant-2')),
        throwsUnsupportedError,
      );
    });
  });
}
