import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FIREFA opens the role entry screen', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FirefaRebuildApp());
    await tester.pumpAndSettle();

    expect(find.text('FIREFA'), findsOneWidget);
    expect(find.text('Restaurant Operating System'), findsOneWidget);
    expect(find.text('Masuk ke FIREFA'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
  });
}
