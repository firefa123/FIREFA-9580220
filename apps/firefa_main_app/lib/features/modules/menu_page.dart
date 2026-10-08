import 'package:flutter/material.dart';


class MenuPage extends StatelessWidget {

  const MenuPage({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return const Center(

      child: Text(

        "Menu",

        style: TextStyle(

          fontSize: 32,

          fontWeight: FontWeight.bold,

        ),

      ),

    );

  }

}