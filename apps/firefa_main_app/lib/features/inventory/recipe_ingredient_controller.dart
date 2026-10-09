import 'recipe_ingredient_model.dart';

class RecipeIngredientController {
  final List<RecipeIngredient> ingredients = [];

  void add(RecipeIngredient ingredient) {
    ingredients.add(ingredient);
  }

  List<RecipeIngredient> findByMenu(String menuId) {
    return ingredients
        .where((item) => item.menuId == menuId)
        .toList();
  }
}
