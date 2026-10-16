import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/customer_store.dart';
import 'package:firefa_main_app/features/modules/order_models.dart';
import 'package:firefa_main_app/features/modules/order_store.dart';

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 test('BON customer credit limit, partial payment, loyalty idempotency, CSV and backup validation', () async {
  SharedPreferences.setMockInitialValues({});
  final orders=FirefaOrderStore.instance, customers=FirefaCustomerStore.instance;
  await orders.initialize(); await customers.initialize();
  const outlet='STAGE6-CUSTOMER';
  expect(customers.add(outletId:outlet,name:'Customer One',phone:'08123456789',creditLimit:20000),isTrue);
  expect(customers.add(outletId:outlet,name:'Duplicate phone',phone:'08123456789',creditLimit:20000),isFalse);
  final customer=customers.forOutlet(outlet).single;
  final order=orders.createOrder(outletId:outlet,orderType:'Take Away',tableId:null,items:[const FirefaOrderItem(productName:'Coffee',quantity:1,unitPrice:15000)],subtotal:15000,discount:0,tax:0,service:0,total:15000);
  expect(await orders.markBonAndPersist(outlet,order.id),isTrue);
  expect(await customers.assignOrder(outletId:outlet,orderId:order.id,customerId:customer.id),isTrue);
  expect(customers.outstanding(outlet,customer.id),15000);
  expect(customers.availableCredit(outlet,customer.id),5000);
  final tooLarge=orders.createOrder(outletId:outlet,orderType:'Take Away',tableId:null,items:[const FirefaOrderItem(productName:'Coffee',quantity:1,unitPrice:10000)],subtotal:10000,discount:0,tax:0,service:0,total:10000);
  await orders.markBonAndPersist(outlet,tooLarge.id);
  expect(await customers.assignOrder(outletId:outlet,orderId:tooLarge.id,customerId:customer.id),isFalse);
  expect(await customers.recordPayment(outletId:outlet,orderId:order.id,amount:5000,method:'Transfer'),isTrue);
  expect(customers.outstanding(outlet,customer.id),15000);
  expect(await customers.recordPayment(outletId:outlet,orderId:order.id,amount:10000,method:'Cash'),isTrue);
  expect(orders.findOrder(outlet,order.id)!.paymentStatus,FirefaPaymentStatus.paid);
  expect(customers.outstanding(outlet,customer.id),15000);
  expect(await customers.assignOrder(outletId:outlet,orderId:tooLarge.id,customerId:customer.id),isFalse);
  final bonPayments = customers.paymentsForOutlet(outlet).where((payment) => payment.orderId == order.id).toList();
  expect(bonPayments, hasLength(2));
  expect(await customers.syncLoyalty(outlet),0);
  for (final payment in bonPayments) {
    expect(payment.verificationStatus, FirefaPaymentVerificationStatus.reported);
    expect(await customers.applyServerReceivablePaymentVerification(
      outletId: outlet,
      paymentId: payment.id,
      verifiedBy: 'owner-test',
    ), isTrue);
  }
  expect(customers.verifiedPaidForOrder(outlet, order.id),15000);
  expect(customers.outstanding(outlet,customer.id),0);
  final fullyPaidBon = orders.findOrder(outlet, order.id)!;
  expect(fullyPaidBon.paymentVerificationStatus, FirefaPaymentVerificationStatus.reported);
  expect(await orders.applyServerPaymentVerification(outlet, order.id, verifiedBy: 'owner-test'), isTrue);
  await orders.waitForPendingSave();
  expect(await customers.assignOrder(outletId:outlet,orderId:tooLarge.id,customerId:customer.id),isTrue);
  expect(customers.outstanding(outlet,customer.id),10000);
  expect(await customers.syncLoyalty(outlet),1);
  final points=customers.find(outlet,customer.id)!.points;
  expect(points,15);
  expect(await customers.syncLoyalty(outlet),0);
  expect(customers.find(outlet,customer.id)!.points,points);
  expect(customers.redeemPoints(outletId:outlet,customerId:customer.id,pointsRequired:10),isTrue);
  expect(customers.find(outlet,customer.id)!.points,5);
  expect(customers.find(outlet,customer.id)!.rewardCount,1);
  final csv=customers.exportCsv(outlet);
  expect(csv,contains('credit_limit'));
  expect(await customers.importCsv(outlet,'name,phone,email,credit_limit,notes\r\nSecond Customer,0812222,second@example.com,50000,New'),1);
  expect(customers.forOutlet(outlet).length,2);
  final snapshot=customers.exportLocalSnapshot();
  customers.validateLocalSnapshot(snapshot);
  expect(() => customers.validateLocalSnapshot({'version':999,'customers':[],'payments':[]}),throwsFormatException);
  await customers.waitForPendingSave(); await orders.waitForPendingSave();
  expect(jsonDecode(jsonEncode(snapshot))['customers'],hasLength(2));
 });
}
