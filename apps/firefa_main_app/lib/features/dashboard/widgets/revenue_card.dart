import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';


class RevenueCard extends StatelessWidget {

  const RevenueCard({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return Card(

      elevation: 0,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),


      child: Padding(

        padding: const EdgeInsets.all(24),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,


          children: [


            Row(

              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,


              children: [


                const Text(

                  "Revenue Overview",

                  style: TextStyle(

                    fontSize: 18,

                    fontWeight:
                        FontWeight.bold,

                  ),

                ),



                Container(

                  padding:
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),


                  decoration: BoxDecoration(

                    color:
                        Colors.green.shade50,


                    borderRadius:
                        BorderRadius.circular(20),

                  ),


                  child: const Text(

                    "Today",

                    style: TextStyle(

                      color:
                          Colors.green,

                      fontSize: 12,

                      fontWeight:
                          FontWeight.w600,

                    ),

                  ),

                ),


              ],

            ),



            const SizedBox(height:24),



            const Text(

              "Rp 8.500.000",

              style: TextStyle(

                fontSize: 32,

                fontWeight:
                    FontWeight.bold,

                color:
                    AppTheme.primary,

              ),

            ),



            const SizedBox(height:8),



            Row(

              children: [


                Container(

                  padding:
                      const EdgeInsets.all(4),


                  decoration:
                      const BoxDecoration(

                        color:
                            Colors.green,

                        shape:
                            BoxShape.circle,

                      ),


                  child:
                      const Icon(

                        Icons.arrow_upward,

                        size:12,

                        color:
                            Colors.white,

                      ),

                ),



                const SizedBox(width:8),



                Text(

                  "+12.5% dibanding kemarin",

                  style: TextStyle(

                    color:
                        Colors.green.shade700,

                    fontWeight:
                        FontWeight.w500,

                  ),

                ),


              ],

            ),



            const SizedBox(height:30),



            SizedBox(

              height:100,


              child: Row(

                crossAxisAlignment:
                    CrossAxisAlignment.end,


                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,


                children: [

                  _bar(35),

                  _bar(55),

                  _bar(45),

                  _bar(75),

                  _bar(65),

                  _bar(90),


                ],

              ),

            ),


          ],

        ),

      ),

    );

  }



  Widget _bar(double height) {

    return Container(

      width:18,

      height:height,

      decoration: BoxDecoration(

        color:
            AppTheme.primary,

        borderRadius:
            BorderRadius.circular(8),

      ),

    );

  }


}