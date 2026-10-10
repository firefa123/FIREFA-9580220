import 'package:flutter/material.dart';


class RecentOrderCard extends StatelessWidget {

  final String order;
  final String item;
  final String status;


  const RecentOrderCard({
    super.key,
    required this.order,
    required this.item,
    required this.status,
  });


  @override
  Widget build(BuildContext context) {


    return Card(

      child:ListTile(

        leading:
            const Icon(
              Icons.receipt_long_outlined,
            ),


        title:
            Text(order),


        subtitle:
            Text(item),


        trailing:
            Text(
              status,
              style:
                const TextStyle(
                  fontWeight:
                    FontWeight.bold,
                ),
            ),

      ),

    );

  }
}