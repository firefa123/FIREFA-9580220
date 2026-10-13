import '../models/menu_item.dart';

class MenuRepository {
  List<MenuItem> getMenus() {
    return const [
      MenuItem(
        id: '1',
        name: 'Nasi Goreng Special',
        category: 'Food',
        price: 25000,
        available: true,
      ),
      MenuItem(
        id: '2',
        name: 'Es Teh',
        category: 'Drink',
        price: 8000,
        available: true,
      ),
    ];
  }
}
