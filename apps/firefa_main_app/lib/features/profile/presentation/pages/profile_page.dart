import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner Account', style: TextStyle(fontSize: 22)),
            SizedBox(height: 12),
            Text('Role: Owner'),
            Text('Subscription: Multi Outlet'),
          ],
        ),
      ),
    );
  }
}
