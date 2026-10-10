import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firefa_main_app/core/theme/app_theme.dart';

void main() {
  test('UI-01 uses the agreed FIREFA palette', () {
    final theme = AppTheme.light;
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, const Color(0xFF008F83));
    expect(theme.colorScheme.onSurface, const Color(0xFF172B4D));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FA));
    expect(theme.cardTheme.color, Colors.white);
  });

  testWidgets('UI-01 primary button and input inherit global theme', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Column(
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Outlet')),
            FilledButton(onPressed: () {}, child: const Text('Simpan')),
          ],
        ),
      ),
    ));
    expect(find.text('Outlet'), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
