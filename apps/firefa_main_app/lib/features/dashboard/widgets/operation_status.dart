import 'package:flutter/material.dart';


class OperationStatus extends StatelessWidget {

  const OperationStatus({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return Card(

      child:Padding(

        padding:
          const EdgeInsets.all(24),

        child:Column(

          crossAxisAlignment:
            CrossAxisAlignment.start,

          children:[


            const Text(
              "Live Operation",
              style:TextStyle(
                fontSize:18,
                fontWeight:FontWeight.bold,
              ),
            ),


            const SizedBox(height:20),


            ListTile(

              leading:
                const Icon(
                  Icons.restaurant,
                ),

              title:
                const Text(
                  "Kitchen",
                ),

              subtitle:
                const Text(
                  "12 Orders Preparing",
                ),

            ),


            ListTile(

              leading:
                const Icon(
                  Icons.local_bar,
                ),

              title:
                const Text(
                  "Bar",
                ),

              subtitle:
                const Text(
                  "8 Drinks Waiting",
                ),

            ),


            ListTile(

              leading:
                const Icon(
                  Icons.table_bar,
                ),

              title:
                const Text(
                  "Tables",
                ),

              subtitle:
                const Text(
                  "5 Available",
                ),

            ),

          ],

        ),

      ),

    );

  }
}