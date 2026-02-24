class PreparationAreaModel {
  final String id;
  final String name;
  final String cafeId;

  PreparationAreaModel({
    required this.id,
    required this.name,
    required this.cafeId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'cafe_id': cafeId,
  };

  factory PreparationAreaModel.fromJson(Map<String, dynamic> json) => PreparationAreaModel(
    id: json['id'],
    name: json['name'],
    cafeId: json['cafe_id'] ?? '',
  );
}
