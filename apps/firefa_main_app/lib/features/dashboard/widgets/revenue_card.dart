import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';


class RevenueCard extends StatelessWidget {

  const RevenueCard({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return Card(

      child: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            const Text(
              "Revenue Overview",

              style: TextStyle(
                fontSize:18,
                fontWeight:FontWeight.bold,
              ),
            ),


            const SizedBox(height:20),


            const Text(
              "Rp 8.500.000",

              style: TextStyle(
                fontSize:32,
                fontWeight:FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),


            const SizedBox(height:8),


            Row(

              children:[

                const Icon(
                  Icons.trending_up,
                  color:Colors.green,
                  size:18,
                ),


                const SizedBox(width:8),


                Text(
                  "+12.5% dibanding kemarin",

                  style: TextStyle(
                    color:Colors.green.shade700,
                  ),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }
}