import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';


class DashboardHeader extends StatelessWidget {

  const DashboardHeader({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        const Text(
          "Good Morning, Owner 👋",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),


        const SizedBox(height: 8),


        Row(

          children: [

            const Icon(
              Icons.store_outlined,
              size: 18,
              color: AppTheme.textSecondary,
            ),


            const SizedBox(width:8),


            const Text(
              "Main Outlet",
              style: TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),


            const SizedBox(width:20),


            Container(

              padding:
                  const EdgeInsets.symmetric(
                    horizontal:12,
                    vertical:6,
                  ),

              decoration: BoxDecoration(

                color:
                    Colors.green.withValues(alpha: 0.1),

                borderRadius:
                    BorderRadius.circular(20),

              ),


              child: const Row(

                children:[

                  Icon(
                    Icons.circle,
                    size:8,
                    color:Colors.green,
                  ),


                  SizedBox(width:6),


                  Text(
                    "Online",
                    style:TextStyle(
                      color:Colors.green,
                      fontSize:12,
                    ),
                  ),

                ],

              ),

            ),

          ],

        ),

      ],

    );

  }
}