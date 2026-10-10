import 'package:flutter_test/flutter_test.dart';

import 'package:firefa_main_app/main.dart';

void main() {
  testWidgets('FIREFA app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const FirefaApp());
    await tester.pumpAndSettle();

    expect(find.text('FIREFA'), findsWidgets);
  });
}
