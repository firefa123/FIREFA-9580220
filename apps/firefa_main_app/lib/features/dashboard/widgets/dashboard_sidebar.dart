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


    return SizedBox(

      width: collapsed ? 80 : 230,


      height: double.infinity,


      child: AnimatedContainer(

        duration:
            const Duration(milliseconds:250),


        padding:
            const EdgeInsets.symmetric(

              horizontal:12,

              vertical:16,

            ),


        child: Column(


          children: [



            Row(

              children: [



                IconButton(

                  icon:
                      const Icon(Icons.menu),


                  onPressed:
                      onToggle,

                ),




                if(!collapsed)

                  const Expanded(

                    child: Text(

                      "FIREFA",

                      style: TextStyle(

                        fontSize:26,

                        fontWeight:
                            FontWeight.bold,

                        letterSpacing:1.5,

                      ),

                    ),

                  ),


              ],


            ),



            const SizedBox(height:30),




            Expanded(


              child: ListView.builder(


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



                    decoration: BoxDecoration(

                      color:

                          active

                          ? Colors.teal.withValues(alpha:0.1)

                          : Colors.transparent,


                      borderRadius:
                          BorderRadius.circular(12),

                    ),



                    child: ListTile(


                      contentPadding:

                          EdgeInsets.symmetric(

                            horizontal:
                                collapsed ? 12 : 16,

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


      ),

    );


  }


}