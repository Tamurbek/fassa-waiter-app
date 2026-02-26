
class FoodVariant {
  final String id;
  final String name;
  final double price;

  FoodVariant({required this.id, required this.name, required this.price});

  factory FoodVariant.fromJson(Map<String, dynamic> json) => FoodVariant(
    id: json['id']?.toString() ?? '',
    name: json['name'] ?? '',
    price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
  };
}

class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;
  final int timeEstimate; // in minutes
  final String preparationArea;
  final String? preparationAreaId;
  final bool hasVariants;
  final List<FoodVariant> variants;

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.category = "General",
    this.rating = 4.5,
    this.timeEstimate = 20,
    this.preparationArea = "Kitchen",
    this.preparationAreaId,
    this.hasVariants = false,
    this.variants = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'category': category,
    'rating': rating,
    'timeEstimate': timeEstimate,
    'preparationArea': preparationArea,
    'preparation_area_id': preparationAreaId,
    'has_variants': hasVariants,
    'variants': variants.map((v) => v.toJson()).toList(),
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    try {
      // Check if it's from backend (has category as object) or local (has category as string)
      String categoryName = "General";
      if (json['category'] != null) {
        if (json['category'] is String) {
          categoryName = json['category'];
        } else if (json['category'] is Map) {
          categoryName = json['category']['name'] ?? "General";
        }
      }

      var variantsList = <FoodVariant>[];
      if (json['variants'] != null && json['variants'] is List) {
        variantsList = (json['variants'] as List)
            .map((v) => FoodVariant.fromJson(v))
            .toList();
      }

      return FoodItem(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
        imageUrl: json['image'] ?? json['imageUrl'] ?? '',
        category: categoryName,
        rating: double.tryParse(json['rating']?.toString() ?? '4.5') ?? 4.5,
        timeEstimate: int.tryParse(json['timeEstimate']?.toString() ?? '20') ?? 20,
        preparationArea: json['preparation_area'] ?? json['preparationArea'] ?? 'Kitchen',
        preparationAreaId: json['preparation_area_id']?.toString(),
        hasVariants: json['has_variants'] ?? false,
        variants: variantsList,
      );
    } catch (e) {
      print("Error parsing FoodItem: $e");
      print("JSON data: $json");
      rethrow;
    }
  }
}
