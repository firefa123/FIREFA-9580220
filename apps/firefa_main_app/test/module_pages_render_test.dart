import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firefa_main_app/core/outlet/active_outlet_store.dart';
import 'package:firefa_main_app/features/modules/customers_page.dart';
import 'package:firefa_main_app/features/modules/finance_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FirefaActiveOutletStore.instance.reset();
  });

  testWidgets('finance page renders its summary and tabs', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FinancePage(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Pembelian & Keuangan'), findsOneWidget);
    expect(find.text('Utang Pemasok'), findsOneWidget);
    expect(find.text('Konsinyasi'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
  });

  testWidgets('customers page renders its tabs and empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomersPage(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Pelanggan & Loyalitas'), findsOneWidget);
    expect(find.text('Pelanggan & RFM'), findsOneWidget);
    expect(find.text('Piutang BON'), findsOneWidget);
    expect(find.text('Loyalty'), findsOneWidget);
    expect(find.text('Belum ada pelanggan. Tambahkan pelanggan untuk mulai.'),
        findsOneWidget);
  });
}
