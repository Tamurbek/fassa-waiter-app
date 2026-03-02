
class FoodVariant {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;
  final int? stockRemaining;
  final DateTime? lastPreparedAt;
  
  FoodVariant({
    required this.id, 
    required this.name, 
    required this.price, 
    this.isAvailable = true,
    this.stockRemaining,
    this.lastPreparedAt,
  });

  factory FoodVariant.fromJson(Map<String, dynamic> json) => FoodVariant(
    id: json['id']?.toString() ?? '',
    name: json['name'] ?? '',
    price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
    isAvailable: json['is_available'] ?? true,
    stockRemaining: json['stock_remaining'],
    lastPreparedAt: json['last_prepared_at'] != null ? DateTime.tryParse(json['last_prepared_at']) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'is_available': isAvailable,
    'stock_remaining': stockRemaining,
    'last_prepared_at': lastPreparedAt?.toIso8601String(),
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
  final bool isAvailable;
  final int? stockRemaining;
  final DateTime? lastPreparedAt;
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
    this.isAvailable = true,
    this.stockRemaining,
    this.lastPreparedAt,
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
    'is_available': isAvailable,
    'stock_remaining': stockRemaining,
    'last_prepared_at': lastPreparedAt?.toIso8601String(),
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
        isAvailable: json['is_available'] ?? true,
        stockRemaining: json['stock_remaining'],
        lastPreparedAt: json['last_prepared_at'] != null ? DateTime.tryParse(json['last_prepared_at']) : null,
        variants: variantsList,
      );
    } catch (e) {
      print("Error parsing FoodItem: $e");
      print("JSON data: $json");
      rethrow;
    }
  }

  bool get isFresh {
    if (lastPreparedAt == null) return false;
    final now = DateTime.now();
    return lastPreparedAt!.year == now.year &&
           lastPreparedAt!.month == now.month &&
           lastPreparedAt!.day == now.day;
  }

  bool get isLowStock => stockRemaining != null && stockRemaining! > 0 && stockRemaining! <= 5;
  bool get isSoldOut => stockRemaining != null && stockRemaining! <= 0;
}

extension DateTimeExtension on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}
