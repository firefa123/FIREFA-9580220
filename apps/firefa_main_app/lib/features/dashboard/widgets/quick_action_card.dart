import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';


class QuickActionCard extends StatelessWidget {

  final String title;
  final IconData icon;


  const QuickActionCard({
    super.key,
    required this.title,
    required this.icon,
  });


  @override
  Widget build(BuildContext context) {

    return Card(

      child: Padding(

        padding:
            const EdgeInsets.all(20),


        child: Column(

          children:[

            Icon(
              icon,
              size:32,
              color:AppTheme.primary,
            ),


            const SizedBox(height:12),


            Text(
              title,
              style:const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),

          ],

        ),

      ),

    );

  }
}