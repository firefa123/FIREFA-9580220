import 'package:flutter/material.dart';


class DashboardSidebar extends StatelessWidget {

  final int selectedIndex;
  final Function(int) onSelected;


  const DashboardSidebar({

    super.key,

    required this.selectedIndex,

    required this.onSelected,

  });



  final menus = const [

    {
      "title":"Dashboard",
      "icon":Icons.dashboard_outlined,
    },

    {
      "title":"POS",
      "icon":Icons.point_of_sale_outlined,
    },

    {
      "title":"Orders",
      "icon":Icons.receipt_long_outlined,
    },

    {
      "title":"Tables",
      "icon":Icons.table_bar_outlined,
    },

    {
      "title":"Menu",
      "icon":Icons.restaurant_menu_outlined,
    },

    {
      "title":"Inventory",
      "icon":Icons.inventory_2_outlined,
    },

    {
      "title":"Reports",
      "icon":Icons.analytics_outlined,
    },

    {
      "title":"Settings",
      "icon":Icons.settings_outlined,
    },

  ];



  @override
  Widget build(BuildContext context){


    return Container(

      width:250,


      padding:
        const EdgeInsets.all(20),


      child:Column(

        crossAxisAlignment:
          CrossAxisAlignment.start,


        children:[


          const Text(

            "FIREFA",

            style:TextStyle(

              fontSize:28,

              fontWeight:
                FontWeight.bold,

              letterSpacing:2,

            ),

          ),


          const SizedBox(height:40),



          Expanded(

            child:ListView.builder(

              itemCount:
                menus.length,


              itemBuilder:(context,index){


                final item =
                  menus[index];


                final active =
                  selectedIndex == index;



                return Container(

                  margin:
                    const EdgeInsets.only(
                      bottom:8,
                    ),


                  decoration:BoxDecoration(

                    color: active
                      ? Colors.teal.withValues(alpha:0.1)
                      : Colors.transparent,


                    borderRadius:
                      BorderRadius.circular(12),

                  ),


                  child:ListTile(

                    leading:
                      Icon(
                        item["icon"] as IconData,
                      ),


                    title:
                      Text(
                        item["title"] as String,
                      ),


                    onTap:(){

                      onSelected(index);

                    },

                  ),

                );


              },

            ),

          ),



          const Divider(),



          const ListTile(

            leading:
              Icon(Icons.cloud_done_outlined),


            title:
              Text(
                "Online",
              ),

          )


        ],

      ),

    );


  }

}