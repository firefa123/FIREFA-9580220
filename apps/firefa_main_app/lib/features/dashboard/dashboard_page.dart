import 'package:flutter/material.dart';

import 'widgets/stat_card.dart';


class DashboardPage extends StatelessWidget {

  const DashboardPage({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          "Dashboard",
        ),

      ),


      body: SingleChildScrollView(

        padding: const EdgeInsets.all(24),


        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,


          children:[


            const Text(

              "Good Morning, Owner",

              style: TextStyle(

                fontSize:28,

                fontWeight:
                    FontWeight.bold,

              ),

            ),


            const SizedBox(height:24),


            LayoutBuilder(

              builder:(context,constraints){


                int columns = 1;


                if(constraints.maxWidth > 900){

                  columns = 4;

                }

                else if(constraints.maxWidth > 600){

                  columns = 2;

                }


                return GridView.count(

                  crossAxisCount: columns,

                  shrinkWrap:true,

                  physics:
                    const NeverScrollableScrollPhysics(),


                  crossAxisSpacing:16,

                  mainAxisSpacing:16,


                  children:[


                    const StatCard(

                      title:"Today's Sales",

                      value:"Rp 8.500.000",

                      icon:
                        Icons.payments_outlined,

                    ),


                    const StatCard(

                      title:"Orders",

                      value:"245",

                      icon:
                        Icons.shopping_bag_outlined,

                    ),


                    const StatCard(

                      title:"Active Tables",

                      value:"18",

                      icon:
                        Icons.table_bar_outlined,

                    ),


                    const StatCard(

                      title:"Low Stock",

                      value:"5",

                      icon:
                        Icons.inventory_2_outlined,

                    ),

                  ],

                );


              },

            ),


          ],

        ),

      ),

    );

  }

}