import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/main.dart';

void main() {
  testWidgets('FIREFA welcome page test', (WidgetTester tester) async {
    await tester.pumpWidget(const FirefaApp());

    expect(find.text('FIREFA'), findsOneWidget);
    expect(
      find.text('Restaurant Operating System'),
      findsOneWidget,
    );
    expect(
      find.text('Mulai Sekarang'),
      findsOneWidget,
    );
  });
}