import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

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
      routes: AppRoutes.routes,
      initialRoute: AppRoutes.dashboard,
    );
  }
}
