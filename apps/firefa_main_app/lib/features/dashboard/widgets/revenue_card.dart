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

        borderRadius:
            BorderRadius.circular(20),

      ),



      child: Padding(

        padding:
            const EdgeInsets.all(24),



        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,



          children: [



            Row(

              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,


              children: [



                const Expanded(

                  child: Text(

                    "Revenue Overview",

                    maxLines: 1,

                    overflow:
                        TextOverflow.ellipsis,


                    style: TextStyle(

                      fontSize:18,

                      fontWeight:
                          FontWeight.bold,

                    ),

                  ),

                ),




                const SizedBox(width:12),




                Container(

                  padding:
                      const EdgeInsets.symmetric(

                        horizontal:10,

                        vertical:5,

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


                      fontSize:12,


                      fontWeight:
                          FontWeight.w600,

                    ),

                  ),

                ),


              ],

            ),




            const SizedBox(height:24),




            FittedBox(

              fit:
                  BoxFit.scaleDown,


              alignment:
                  Alignment.centerLeft,



              child: const Text(

                "Rp 8.500.000",


                style: TextStyle(

                  fontSize:32,


                  fontWeight:
                      FontWeight.bold,


                  color:
                      AppTheme.primary,

                ),

              ),

            ),




            const SizedBox(height:12),




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



                  child: const Icon(

                    Icons.arrow_upward,


                    size:12,


                    color:
                        Colors.white,

                  ),

                ),




                const SizedBox(width:8),




                const Expanded(

                  child: Text(

                    "+12.5% dibanding kemarin",


                    maxLines:2,


                    overflow:
                        TextOverflow.ellipsis,



                    style: TextStyle(

                      color:
                          Colors.green,


                      fontWeight:
                          FontWeight.w500,

                    ),

                  ),

                ),



              ],

            ),




            const SizedBox(height:30),




            SizedBox(

              height:100,



              child: LayoutBuilder(

                builder:
                    (context,constraints){



                  return Row(

                    crossAxisAlignment:
                        CrossAxisAlignment.end,


                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,



                    children: [



                      _bar(constraints.maxWidth,35),

                      _bar(constraints.maxWidth,55),

                      _bar(constraints.maxWidth,45),

                      _bar(constraints.maxWidth,75),

                      _bar(constraints.maxWidth,65),

                      _bar(constraints.maxWidth,90),



                    ],


                  );


                },

              ),

            ),



          ],


        ),

      ),

    );


  }




  Widget _bar(double width,double height){


    return Container(

      width:
          width < 250 ? 12 : 18,


      height:
          height,


      decoration: BoxDecoration(

        color:
            AppTheme.primary,


        borderRadius:
            BorderRadius.circular(8),

      ),

    );


  }


}