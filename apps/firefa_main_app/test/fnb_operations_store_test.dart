import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/fnb_operations_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FirefaFnbOperationsStore.instance.initialize();
  });
  test('reservation JSON round trip preserves schedule and status', () {
    final value = FirefaReservation(id:'RSV-1', outletId:'outlet-a', guest:'Nisa',
      phone:'0812', partySize:4, at:DateTime(2026,10,20,19), status:'booked', table:'A1');
    final copy = FirefaReservation.fromJson(value.toJson());
    expect(copy.guest, 'Nisa');
    expect(copy.partySize, 4);
    expect(copy.at, value.at);
    expect(copy.table, 'A1');
  });
  test('queue status transition preserves queue number', () {
    final value = FirefaQueueTicket(id:'queue-Q001', outletId:'outlet-a',
      number:'Q001', guest:'Tamu', partySize:2, at:DateTime(2026), status:'waiting');
    final called = value.withStatus('called');
    expect(called.number, 'Q001');
    expect(called.status, 'called');
  });
  test('promo validates active window and caps discount at subtotal', () {
    final promo = FirefaPromo(id:'P1',outletId:'o1',name:'Hemat',code:'HEMAT',
      type:'percent',value:20,minimum:50000,start:DateTime(2026,1),end:DateTime(2026,12,31),active:true);
    expect(promo.discountAt(DateTime(2026,10),100000),20000);
    expect(promo.discountAt(DateTime(2026,10),20000),0);
    expect(promo.discountAt(DateTime(2027,1),100000),0);
  });
  test('promo code is required when a promo has a code and type pricing validates', () async {
    final store = FirefaFnbOperationsStore.instance;
    final now = DateTime.now();
    expect(store.savePromo(outlet:'promo-test-outlet',name:'Promo Kode',code:'HEMAT20',type:'percent',value:20,minimum:10000,start:now.subtract(const Duration(days:1)),end:now.add(const Duration(days:1))),true);
    expect(store.promoDiscount('promo-test-outlet',50000),0);
    expect(store.promoDiscount('promo-test-outlet',50000,code:'hemat20'),10000);
    expect(store.savePrice(outlet:'promo-test-outlet',type:'Delivery',fee:5000,percent:10),true);
    expect(store.typeFee('promo-test-outlet','Delivery',50000),10000);
  });
  test('reservation prevents nearby table overlap and enforces status lifecycle', () async {
    final store = FirefaFnbOperationsStore.instance;
    final outlet = 'reservation-lifecycle-test';
    final start = DateTime.now().add(const Duration(hours:4));
    expect(store.addReservation(outlet:outlet,guest:'Guest A',phone:'',partySize:2,at:start,table:'A-01'),true);
    expect(store.addReservation(outlet:outlet,guest:'Guest B',phone:'',partySize:2,at:start.add(const Duration(minutes:60)),table:'a-01'),false);
    expect(store.addReservation(outlet:outlet,guest:'Guest C',phone:'',partySize:2,at:start.add(const Duration(hours:3)),table:'A-01'),true);
    final reservation = store.reservations(outlet).first;
    expect(store.setReservationStatus(outlet,reservation.id,'seated'),false);
    expect(store.setReservationStatus(outlet,reservation.id,'arrived'),true);
    expect(store.setReservationStatus(outlet,reservation.id,'seated'),true);
    expect(store.setReservationStatus(outlet,reservation.id,'completed'),true);
    await store.waitForPendingSave();
  });
  test('queue follows waiting called seated completed lifecycle', () async {
    final store = FirefaFnbOperationsStore.instance;
    const outlet = 'queue-lifecycle-test';
    expect(store.addQueue(outlet:outlet,guest:'Queue Guest',partySize:3),true);
    final ticket = store.queue(outlet).single;
    expect(store.setQueueStatus(outlet,ticket.id,'seated'),false);
    expect(store.setQueueStatus(outlet,ticket.id,'called'),true);
    expect(store.setQueueStatus(outlet,ticket.id,'seated'),true);
    expect(store.setQueueStatus(outlet,ticket.id,'completed'),true);
    await store.waitForPendingSave();
  });
  test('bundle serializes its component quantities', () {
    final bundle = FirefaMenuBundle(id:'B1',outletId:'o1',name:'Paket A',
      lines:const [FirefaBundleLine('Nasi',2),FirefaBundleLine('Teh',1)],
      price:45000,active:true);
    final copy = FirefaMenuBundle.fromJson(bundle.toJson());
    expect(copy.lines.length,2);
    expect(copy.lines.first.quantity,2);
    expect(copy.price,45000);
  });
}
