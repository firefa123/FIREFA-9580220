import 'package:flutter/material.dart';

import 'widgets/stat_card.dart';
import 'widgets/revenue_card.dart';
import 'widgets/dashboard_sidebar.dart';


class DashboardPage extends StatefulWidget {

  const DashboardPage({
    super.key,
  });


  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();

}



class _DashboardPageState extends State<DashboardPage> {


  int selectedIndex = 0;

  bool sidebarCollapsed = true;



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      body: Row(

        children: [



          DashboardSidebar(

            selectedIndex: selectedIndex,


            collapsed: sidebarCollapsed,


            onToggle: (){

              setState((){

                sidebarCollapsed =
                    !sidebarCollapsed;

              });

            },


            onSelected: (index){

              setState((){

                selectedIndex = index;

              });

            },

          ),




          Expanded(

            child: SingleChildScrollView(

              padding:
                  const EdgeInsets.all(24),



              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,


                children: [


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


                      if(constraints.maxWidth > 1000){

                        columns = 4;

                      }

                      else if(constraints.maxWidth > 600){

                        columns = 2;

                      }



                      return GridView.count(

                        crossAxisCount:
                            columns,


                        shrinkWrap:true,


                        physics:
                            const NeverScrollableScrollPhysics(),


                        crossAxisSpacing:16,


                        mainAxisSpacing:16,



                        children: const [



                          StatCard(

                            title:"Today's Sales",

                            value:"Rp 8.500.000",

                            icon:
                              Icons.payments_outlined,

                          ),



                          StatCard(

                            title:"Orders",

                            value:"245",

                            icon:
                              Icons.shopping_bag_outlined,

                          ),



                          StatCard(

                            title:"Active Tables",

                            value:"18",

                            icon:
                              Icons.table_bar_outlined,

                          ),



                          StatCard(

                            title:"Low Stock",

                            value:"5",

                            icon:
                              Icons.inventory_2_outlined,

                          ),


                        ],

                      );


                    },

                  ),



                  const SizedBox(height:24),



                  const RevenueCard(),



                  const SizedBox(height:24),



                  const Card(

                    child: Padding(

                      padding:
                        EdgeInsets.all(24),


                      child: Text(

                        "Live Operation\n\nKitchen : 12 Orders Cooking\nTables : 18 Occupied",

                      ),

                    ),

                  ),



                ],

              ),

            ),

          ),


        ],

      ),

    );


  }


}