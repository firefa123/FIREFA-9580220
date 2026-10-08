import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';



class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}


class _LoginFormState extends State<LoginForm> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool rememberMe = false;
  bool obscurePassword = true;


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: "Email",
            prefixIcon: Icon(
              Icons.email_outlined,
            ),
          ),
        ),


        const SizedBox(height: 16),


        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          decoration: InputDecoration(
            labelText: "Password",
            prefixIcon: const Icon(
              Icons.lock_outline,
            ),

            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),

              onPressed: () {
                setState(() {
                  obscurePassword = !obscurePassword;
                });
              },
            ),
          ),
        ),


        const SizedBox(height: 16),


        Row(
          children: [

            Checkbox(
              value: rememberMe,
              onChanged: (value) {
                setState(() {
                  rememberMe = value ?? false;
                });
              },
            ),


            const Text(
              "Remember me",
            ),


            const Spacer(),


            TextButton(
              onPressed: () {},
              child: const Text(
                "Forgot password?",
              ),
            ),

          ],
        ),


        const SizedBox(height: 20),


        SizedBox(
          width: double.infinity,
          height: 50,

          child: FilledButton(
            onPressed: () {

              // sementara dummy login

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    "Login FIREFA berhasil dipanggil",
                  ),
                ),
              );

            },

            child: const Text(
              "LOGIN",
            ),
          ),
        ),


      ],
    );
  }
}