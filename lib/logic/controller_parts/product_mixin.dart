import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../data/models/preparation_area_model.dart';
import 'pos_controller_state.dart';

mixin ProductMixin on POSControllerState {
  Future<void> addProduct(FoodItem item) async {
    try {
      final json = item.toJson();
      json['cafe_id'] = cafeId;
      json['image'] = item.imageUrl;
      final cat = categoriesObjects.firstWhereOrNull((c) => c['name'] == item.category);
      if (cat != null) json['category_id'] = cat['id'];

      final newItem = await api.createProduct(json);
      products.add(FoodItem.fromJson(newItem));
      saveProducts();
    } catch (e) { print("Error adding product: $e"); }
  }

  Future<void> updateProduct(FoodItem item) async {
    try {
      final json = item.toJson();
      json.remove('id');
      json['cafe_id'] = cafeId;
      json['image'] = item.imageUrl;
      final cat = categoriesObjects.firstWhereOrNull((c) => c['name'] == item.category);
      if (cat != null) json['category_id'] = cat['id'];

      final updatedItem = await api.updateProduct(item.id, json);
      int index = products.indexWhere((p) => p.id == item.id);
      if (index != -1) {
        products[index] = FoodItem.fromJson(updatedItem);
        saveProducts();
      }
    } catch (e) { print("Error updating product: $e"); }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await api.deleteProduct(id);
      products.removeWhere((p) => p.id == id);
      saveProducts();
    } catch (e) { print("Error deleting product: $e"); }
  }

  Future<void> addCategory(String category) async {
    if (categories.contains(category)) return;
    try {
      final newCat = await api.createCategory({
        "name": category,
        "cafe_id": cafeId,
        "sort_order": categories.length
      });
      categoriesObjects.add(newCat);
      categories.add(newCat['name']);
      storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
    } catch (e) { print("Error adding category: $e"); }
  }
  
  Future<void> updateCategory(String oldName, String newName) async {
    final catObj = categoriesObjects.firstWhereOrNull((c) => c['name'] == oldName);
    if (catObj == null) return;
    try {
      final updatedCat = await api.updateCategory(catObj['id'], {"name": newName});
      int objIndex = categoriesObjects.indexWhere((c) => c['id'] == catObj['id']);
      if (objIndex != -1) categoriesObjects[objIndex] = updatedCat;
      int nameIndex = categories.indexOf(oldName);
      if (nameIndex != -1) categories[nameIndex] = newName;
      storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
      fetchBackendData(); // Refresh products with new category name
    } catch (e) { print("Error updating category: $e"); }
  }

  Future<void> deleteCategory(String category) async {
    if (category == "All") return;
    final catObj = categoriesObjects.firstWhereOrNull((c) => c['name'] == category);
    if (catObj == null) return;
    try {
      await api.deleteCategory(catObj['id']);
      categoriesObjects.removeWhere((c) => c['id'] == catObj['id']);
      categories.remove(category);
      storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
    } catch (e) { print("Error deleting category: $e"); }
  }

  Future<void> addPreparationArea(PreparationAreaModel area) async {
    try {
      final json = area.toJson();
      json['cafe_id'] = cafeId;
      final newArea = await api.createPreparationArea(json);
      preparationAreas.add(PreparationAreaModel.fromJson(newArea));
      savePreparationAreas();
    } catch (e) { print("Error adding preparation area: $e"); }
  }

  Future<void> updatePreparationArea(PreparationAreaModel area) async {
    try {
      final json = area.toJson();
      json.remove('id');
      final updatedArea = await api.updatePreparationArea(area.id, json);
      int index = preparationAreas.indexWhere((a) => a.id == area.id);
      if (index != -1) {
        preparationAreas[index] = PreparationAreaModel.fromJson(updatedArea);
        savePreparationAreas();
      }
    } catch (e) { print("Error updating preparation area: $e"); }
  }

  Future<void> deletePreparationArea(String id) async {
    try {
      await api.deletePreparationArea(id);
      preparationAreas.removeWhere((a) => a.id == id);
      savePreparationAreas();
    } catch (e) { print("Error deleting preparation area: $e"); }
  }
}
