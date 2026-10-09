import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/layout/app_shell.dart';

void main() {
  runApp(const FirefaApp());
}

class FirefaApp extends StatelessWidget {
  const FirefaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIREFA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppShell(),
    );
  }
}
