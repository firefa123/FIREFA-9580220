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

    ("Dashboard", Icons.dashboard_outlined),

    ("POS", Icons.point_of_sale_outlined),

    ("Orders", Icons.receipt_long_outlined),

    ("Tables", Icons.table_bar_outlined),

    ("Menu", Icons.restaurant_menu_outlined),

    ("Inventory", Icons.inventory_2_outlined),

    ("Reports", Icons.analytics_outlined),

    ("Settings", Icons.settings_outlined),

  ];



  @override
  Widget build(BuildContext context) {


    return AnimatedContainer(

      duration:
          const Duration(milliseconds:250),


      width:
          collapsed ? 70 : 230,


      child: Column(

        children: [


          SizedBox(

            height:60,


            child:

              collapsed

              ? Center(

                  child: IconButton(

                    icon:
                        const Icon(Icons.menu),

                    onPressed:
                        onToggle,

                  ),

                )


              : Row(

                  children:[


                    IconButton(

                      icon:
                          const Icon(Icons.menu),

                      onPressed:
                          onToggle,

                    ),


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

          ),




          Expanded(

            child: ListView.builder(

              itemCount:
                  menus.length,


              itemBuilder:(context,index){


                final item =
                    menus[index];


                final active =
                    selectedIndex == index;



                return Padding(

                  padding:

                    const EdgeInsets.symmetric(

                      vertical:4,

                    ),



                  child: InkWell(

                    borderRadius:
                        BorderRadius.circular(12),


                    onTap:(){

                      onSelected(index);

                    },



                    child: Container(

                      height:48,


                      alignment:

                        collapsed

                        ? Alignment.center

                        : Alignment.centerLeft,



                      decoration:BoxDecoration(

                        color:

                          active

                          ? Colors.teal.withValues(alpha:0.1)

                          : Colors.transparent,


                        borderRadius:

                          BorderRadius.circular(12),

                      ),



                      child:

                        collapsed

                        ? Icon(item.$2)


                        : Row(

                            children:[


                              const SizedBox(width:16),



                              Icon(item.$2),



                              const SizedBox(width:12),



                              Text(item.$1),


                            ],

                          ),

                    ),

                  ),

                );


              },


            ),

          ),



          const Divider(),



          collapsed

          ? const Icon(
              Icons.cloud_done_outlined,
            )

          : const Row(

              children:[

                SizedBox(width:16),

                Icon(
                  Icons.cloud_done_outlined,
                ),

                SizedBox(width:10),

                Text("Online"),

              ],

            ),


          const SizedBox(height:16),

        ],

      ),

    );


  }


}