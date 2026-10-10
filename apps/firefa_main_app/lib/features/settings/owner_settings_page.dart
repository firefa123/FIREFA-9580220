import 'package:flutter/material.dart';

class OwnerSettingsPage extends StatelessWidget {
  const OwnerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            leading: Icon(Icons.store),
            title: Text('Profil Toko'),
          ),
          ListTile(
            leading: Icon(Icons.palette),
            title: Text('Branding'),
          ),
          ListTile(
            leading: Icon(Icons.dark_mode),
            title: Text('Appearance'),
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text('Staff Management'),
          ),
        ],
      ),
    );
  }
}
