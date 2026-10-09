import 'customer_menu_model.dart';

class CustomerMenuController {
  final List<CustomerMenuModel> _menus = [];

  List<CustomerMenuModel> get menus => List.unmodifiable(_menus);

  void addMenu(CustomerMenuModel menu) {
    _menus.add(menu);
  }

  List<CustomerMenuModel> get availableMenus =>
      _menus.where((menu) => menu.available).toList();
}
