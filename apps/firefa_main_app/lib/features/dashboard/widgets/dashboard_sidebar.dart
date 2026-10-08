import 'package:flutter/material.dart';


class DashboardSidebar extends StatelessWidget {

  final int selectedIndex;
  final Function(int) onSelected;
  final bool collapsed;
  final VoidCallback onToggle;


  const DashboardSidebar({

    super.key,

    required this.selectedIndex,

    required this.onSelected,

    required this.collapsed,

    required this.onToggle,

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
  Widget build(BuildContext context) {


    return AnimatedContainer(

      duration:
          const Duration(milliseconds:250),


      width:
          collapsed ? 80 : 230,


      padding:
          const EdgeInsets.symmetric(

            horizontal:10,

            vertical:16,

          ),



      child: Column(

        children:[


          Row(

            mainAxisAlignment:

              collapsed

              ? MainAxisAlignment.center

              : MainAxisAlignment.start,


            children:[


              IconButton(

                icon:
                    const Icon(Icons.menu),


                onPressed:
                    onToggle,

              ),



              if(!collapsed)

                const Text(

                  "FIREFA",

                  style:TextStyle(

                    fontSize:24,

                    fontWeight:
                        FontWeight.bold,

                  ),

                ),


            ],

          ),



          const SizedBox(height:30),



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

                    color:

                      active

                      ? Colors.teal.withValues(alpha:0.1)

                      : Colors.transparent,


                    borderRadius:
                        BorderRadius.circular(12),

                  ),



                  child:ListTile(


                    contentPadding:
                        EdgeInsets.symmetric(

                          horizontal:
                              collapsed ? 12 : 8,

                        ),



                    leading:

                        Icon(

                          item["icon"] as IconData,

                        ),



                    title:

                      collapsed

                      ? null

                      : Text(

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



          Icon(

            Icons.cloud_done_outlined,

          ),



          if(!collapsed)

            const Text(

              "Online",

            ),



        ],

      ),

    );


  }


}