import 'package:flutter/material.dart';

import '../../../core/auth/role_permissions.dart';
import '../../dashboard/dashboard_page.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscurePassword = true;
  bool rememberMe = false;

  FirefaRole selectedRole = FirefaRole.owner;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(role: selectedRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () {
                setState(() => obscurePassword = !obscurePassword);
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<FirefaRole>(
          initialValue: selectedRole,
          decoration: const InputDecoration(
            labelText: 'Login as (Demo)',
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: FirefaRole.values.map((role) {
            return DropdownMenuItem(
              value: role,
              child: Text(role.label),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => selectedRole = value);
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: rememberMe,
              onChanged: (value) {
                setState(() => rememberMe = value ?? false);
              },
            ),
            const Text('Remember me'),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text('Forgot password?'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _login,
            child: const Text('LOGIN (DEMO)'),
          ),
        ),
      ],
    );
  }
}
