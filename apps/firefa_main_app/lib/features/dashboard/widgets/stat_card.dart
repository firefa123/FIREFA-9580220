import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';


class StatCard extends StatelessWidget {

  final String title;
  final String value;
  final IconData icon;


  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });


  @override
  Widget build(BuildContext context) {

    return Card(

      child: Padding(

        padding: const EdgeInsets.all(20),

        child: Row(

          children: [

            Container(

              width:48,
              height:48,

              decoration: BoxDecoration(

                color: AppTheme.primary.withOpacity(0.1),

                borderRadius:
                    BorderRadius.circular(14),

              ),

              child: Icon(
                icon,
                color: AppTheme.primary,
              ),

            ),


            const SizedBox(width:16),


            Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children:[

                Text(

                  title,

                  style: const TextStyle(

                    fontSize:14,

                    color:
                      AppTheme.textSecondary,

                  ),

                ),


                const SizedBox(height:4),


                Text(

                  value,

                  style: const TextStyle(

                    fontSize:22,

                    fontWeight:
                      FontWeight.bold,

                    color:
                      AppTheme.textPrimary,

                  ),

                ),

              ],

            )

          ],

        ),

      ),

    );

  }
}