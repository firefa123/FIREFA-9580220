import 'package:flutter/material.dart';

class OwnerSettingsEntryPage extends StatelessWidget {
  const OwnerSettingsEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Settings'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profil Toko'),
            SizedBox(height: 12),
            Text('Branding'),
            SizedBox(height: 12),
            Text('Appearance'),
            SizedBox(height: 12),
            Text('Staff Management'),
          ],
        ),
      ),
    );
  }
}
