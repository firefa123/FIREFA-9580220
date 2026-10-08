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

  bool obscurePassword = true;
  bool rememberMe = false;

  String selectedRole = "Owner";


  final roles = [
    "Owner",
    "Manager",
    "Cashier",
    "Kitchen / Bar",
  ];


  @override
  Widget build(BuildContext context) {

    return Column(
      children: [

        TextField(
          controller: emailController,

          decoration: const InputDecoration(
            labelText: "Email",
            prefixIcon: Icon(
              Icons.email_outlined,
            ),
          ),
        ),


        const SizedBox(height:16),


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

              onPressed: (){
                setState(() {
                  obscurePassword =
                      !obscurePassword;
                });
              },

            ),
          ),
        ),


        const SizedBox(height:20),


        DropdownButtonFormField<String>(

          value:selectedRole,

          decoration: const InputDecoration(
            labelText:"Login as",
            prefixIcon: Icon(
              Icons.person_outline,
            ),
          ),


          items: roles.map((role){

            return DropdownMenuItem(
              value: role,
              child: Text(role),
            );

          }).toList(),


          onChanged:(value){

            setState(() {
              selectedRole=value!;
            });

          },

        ),


        const SizedBox(height:16),


        Row(

          children:[

            Checkbox(

              value:rememberMe,

              onChanged:(value){

                setState(() {
                  rememberMe=value ?? false;
                });

              },

            ),


            const Text(
              "Remember me",
            ),


            const Spacer(),


            TextButton(

              onPressed:(){},

              child:const Text(
                "Forgot password?",
              ),

            ),

          ],

        ),


        const SizedBox(height:20),


        SizedBox(

          width:double.infinity,

          height:52,


          child:FilledButton(

            onPressed:(){

              ScaffoldMessenger
                  .of(context)
                  .showSnackBar(

                SnackBar(

                  content:Text(
                    "Login sebagai $selectedRole",
                  ),

                ),

              );

            },


            child:const Text(
              "LOGIN",
            ),

          ),

        ),

      ],
    );
  }
}