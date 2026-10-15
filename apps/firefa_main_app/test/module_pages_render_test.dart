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
    await tester.pumpAndSettle();

    expect(find.text('Pembelian & Keuangan'), findsOneWidget);
    expect(find.text('Utang Pemasok'), findsOneWidget);
    expect(find.text('Konsinyasi'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
  });

  testWidgets('customers page starts safely while loading its local stores',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomersPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
