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



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      body: Row(

        children: [


          DashboardSidebar(

            selectedIndex: selectedIndex,

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

                      fontSize: 28,

                      fontWeight:
                          FontWeight.bold,

                    ),

                  ),



                  const SizedBox(height:24),



                  LayoutBuilder(

                    builder:
                    (context,constraints){


                      int columns = 1;



                      if(constraints.maxWidth > 900){

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

                            "Today's Sales",

                            "Rp 8.500.000",

                            Icons.payments_outlined,

                          ),



                          StatCard(

                            "Orders",

                            "245",

                            Icons.shopping_bag_outlined,

                          ),



                          StatCard(

                            "Active Tables",

                            "18",

                            Icons.table_bar_outlined,

                          ),



                          StatCard(

                            "Low Stock",

                            "5",

                            Icons.inventory_2_outlined,

                          ),


                        ],


                      );


                    },

                  ),



                  const SizedBox(height:24),



                  const RevenueCard(),



                  const SizedBox(height:24),



                  Card(

                    child: Padding(

                      padding:
                          const EdgeInsets.all(24),


                      child: Column(

                        crossAxisAlignment:
                            CrossAxisAlignment.start,


                        children: const [


                          Text(

                            "Live Operation",

                            style: TextStyle(

                              fontSize:18,

                              fontWeight:
                                  FontWeight.bold,

                            ),

                          ),


                          SizedBox(height:16),


                          Text(
                            "Kitchen : 12 Orders Cooking",
                          ),


                          SizedBox(height:8),


                          Text(
                            "Tables : 18 Occupied",
                          ),


                        ],


                      ),

                    ),

                  ),



                  const SizedBox(height:24),



                  Card(

                    child: Padding(

                      padding:
                          const EdgeInsets.all(24),


                      child: Column(

                        crossAxisAlignment:
                            CrossAxisAlignment.start,


                        children: const [


                          Text(

                            "Recent Orders",

                            style: TextStyle(

                              fontSize:18,

                              fontWeight:
                                  FontWeight.bold,

                            ),

                          ),


                          SizedBox(height:16),


                          Text(
                            "#1025 - Table 05 - Preparing",
                          ),


                          SizedBox(height:8),


                          Text(
                            "#1026 - Table 02 - Completed",
                          ),


                        ],


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