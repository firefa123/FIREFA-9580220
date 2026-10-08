import 'package:flutter/material.dart';

import 'widgets/firefa_logo.dart';
import 'widgets/login_form.dart';


class LoginPage extends StatelessWidget {
  const LoginPage({
    super.key,
  });


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),

            child: LayoutBuilder(
              builder: (context, constraints) {

                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),

                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: [

                          const FirefaLogo(),

                          const SizedBox(height: 40),

                          const LoginForm(),

                        ],
                      ),
                    ),
                  ),
                );

              },
            ),
          ),
        ),
      ),
    );
  }
}