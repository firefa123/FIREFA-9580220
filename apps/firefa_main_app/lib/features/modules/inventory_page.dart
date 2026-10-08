import 'package:flutter/material.dart';


class InventoryPage extends StatelessWidget {

  const InventoryPage({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return const Center(

      child: Text(

        "Orders",

        style: TextStyle(

          fontSize: 32,

          fontWeight: FontWeight.bold,

        ),

      ),

    );

  }

}