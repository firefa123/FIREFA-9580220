import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_staff_app/main.dart';

void main() {
  testWidgets('dashboard shows the four main sections', (tester) async {
    await tester.pumpWidget(const FirefaStaffApp());
    expect(find.text('FIREFA Staff'), findsOneWidget);
    expect(find.text('Tim FIREFA'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Shift'), findsOneWidget);
    expect(find.text('Tugas'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });

  testWidgets('staff can toggle the demo shift', (tester) async {
    await tester.pumpWidget(const FirefaStaffApp());
    expect(find.text('Mulai Shift (Demo)'), findsOneWidget);
    await tester.tap(find.text('Mulai Shift (Demo)'));
    await tester.pump();
    expect(find.text('Akhiri Shift (Demo)'), findsOneWidget);
    expect(find.text('Shift sedang berjalan'), findsOneWidget);
  });

  testWidgets('staff can mark a task complete', (tester) async {
    await tester.pumpWidget(const FirefaStaffApp());
    await tester.tap(find.text('Tugas'));
    await tester.pumpAndSettle();
    expect(find.text('0 dari 3 tugas selesai'), findsOneWidget);
    await tester.tap(find.text('Persiapan area kerja'));
    await tester.pumpAndSettle();
    expect(find.text('1 dari 3 tugas selesai'), findsOneWidget);
  });
}
