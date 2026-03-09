class PrinterModel {
  final String id;
  final String name;
  final String? ipAddress;
  final int port;
  final String connectionType;
  final bool isActive;
  final String cafeId;
  final List<String> preparationAreaIds;
  final List<String> tableAreaNames;
  final bool printReceipts;
  final bool printPayments;
  final bool printBill;
  final String paperSize;

  PrinterModel({
    required this.id,
    required this.name,
    this.ipAddress,
    this.port = 9100,
    this.connectionType = 'NETWORK',
    this.isActive = true,
    required this.cafeId,
    this.preparationAreaIds = const [],
    this.tableAreaNames = const [],
    this.printReceipts = false,
    this.printPayments = false,
    this.printBill = false,
    this.paperSize = '80mm',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ip_address': ipAddress,
    'port': port,
    'connection_type': connectionType,
    'is_active': isActive,
    'cafe_id': cafeId,
    'preparation_area_ids': preparationAreaIds,
    'table_area_names': tableAreaNames,
    'print_receipts': printReceipts,
    'print_payments': printPayments,
    'print_bill': printBill,
    'paper_size': paperSize,
  };

  factory PrinterModel.fromJson(Map<String, dynamic> json) {
    List<String> areas = [];
    if (json['preparation_area_ids'] != null) {
      areas = List<String>.from(json['preparation_area_ids'] as List);
    } else if (json['preparation_area_id'] != null && json['preparation_area_id'].toString().isNotEmpty) {
      areas = [json['preparation_area_id'].toString()];
    }

    return PrinterModel(
      id: json['id'],
      name: json['name'],
      ipAddress: json['ip_address'],
      port: json['port'] ?? 9100,
      connectionType: json['connection_type'] ?? 'NETWORK',
      isActive: json['is_active'] ?? true,
      cafeId: json['cafe_id'] ?? '',
      preparationAreaIds: areas,
      tableAreaNames: List<String>.from(json['table_area_names'] ?? []),
      printReceipts: json['print_receipts'] ?? false,
      printPayments: json['print_payments'] ?? false,
      printBill: json['print_bill'] ?? false,
      paperSize: json['paper_size'] ?? '80mm',
    );
  }
}
