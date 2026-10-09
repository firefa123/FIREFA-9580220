import 'package:flutter/material.dart';

import '../auth/role_permissions.dart';
import 'app_routes.dart';

class FirefaMainNavigation extends StatefulWidget {
  final FirefaRole role;

  const FirefaMainNavigation({super.key, required this.role});

  @override
  State<FirefaMainNavigation> createState() => _FirefaMainNavigationState();
}

class _FirefaMainNavigationState extends State<FirefaMainNavigation> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final modules = FirefaNavigation.accessibleModules(widget.role);

    if (modules.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Tidak ada modul tersedia')),
      );
    }

    final selectedModule = modules[selectedIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedModule.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                widget.role.name.toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selectedModule.icon, size: 56),
                const SizedBox(height: 16),
                Text(
                  selectedModule.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  selectedModule.description,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: [
          for (final module in modules.take(5))
            NavigationDestination(
              icon: Icon(module.icon),
              label: module.title,
            ),
        ],
      ),
    );
  }
}
