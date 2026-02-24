import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../data/models/food_item.dart';
import '../../data/models/printer_model.dart';
import '../../data/models/preparation_area_model.dart';
import 'pos_controller_state.dart';

mixin DataSyncMixin on POSControllerState {
  Future<void> refreshData({bool showMessage = true}) async {
    try {
      await fetchBackendData();
      if (showMessage) {
        Get.snackbar("Yangilandi", "Ma'lumotlar muvaffaqiyatli yangilandi",
          backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
      }
    } catch (e) { print("Refresh error: $e"); }
  }

  Future<void> fetchBackendData() async {
    if (currentUser.value == null) return;
    
    await Future.wait([
      // 1. Fetch Cafe Info
      () async {
        try {
          final cafe = await api.getCafe(cafeId);
          restaurantName.value = cafe['name'] ?? "";
          restaurantAddress.value = cafe['address'] ?? "";
          restaurantPhone.value = cafe['phone'] ?? "";
          restaurantLogo.value = cafe['logo'] ?? "";
          currency.value = cafe['currency'] ?? "UZS";
          serviceFeeDineIn.value = (cafe['service_fee_dine_in'] ?? 10.0).toDouble();
          serviceFeeTakeaway.value = (cafe['service_fee_takeaway'] ?? 0.0).toDouble();
          serviceFeeDelivery.value = (cafe['service_fee_delivery'] ?? 3000.0).toDouble();
          
          receiptStyle.value = cafe['receipt_style'] ?? "STANDARD";
          receiptHeader.value = cafe['receipt_header'] ?? "";
          receiptFooter.value = cafe['receipt_footer'] ?? "Xaridingiz uchun rahmat!";
          showLogo.value = cafe['show_logo'] ?? true;
          showWaiter.value = cafe['show_waiter'] ?? true;
          showWifi.value = cafe['show_wifi'] ?? false;
          wifiSsid.value = cafe['wifi_ssid'] ?? "";
          wifiPassword.value = cafe['wifi_password'] ?? "";
          instagram.value = cafe['instagram'] ?? "";
          telegram.value = cafe['telegram'] ?? "";
          allowWaiterMobileOrders.value = cafe['allow_waiter_mobile_orders'] ?? true;
          
          storage.write('restaurant_name', restaurantName.value);
          storage.write('restaurant_address', restaurantAddress.value);
          storage.write('restaurant_phone', restaurantPhone.value);
          storage.write('restaurant_logo', restaurantLogo.value);
          storage.write('currency', currency.value);
          storage.write('service_fee_dine_in', serviceFeeDineIn.value);
          storage.write('service_fee_takeaway', serviceFeeTakeaway.value);
          storage.write('service_fee_delivery', serviceFeeDelivery.value);
          
          storage.write('receipt_style', receiptStyle.value);
          storage.write('receipt_header', receiptHeader.value);
          storage.write('receipt_footer', receiptFooter.value);
          storage.write('show_logo', showLogo.value);
          storage.write('show_waiter', showWaiter.value);
          storage.write('show_wifi', showWifi.value);
          storage.write('wifi_ssid', wifiSsid.value);
          storage.write('wifi_password', wifiPassword.value);
          storage.write('instagram', instagram.value);
          storage.write('telegram', telegram.value);
          storage.write('allow_waiter_mobile_orders', allowWaiterMobileOrders.value);
        } catch (e) { print("Error fetching cafe info: $e"); }
      }(),

      // 2. Fetch Categories
      () async {
        try {
          final backendCategories = await api.getCategories();
          categoriesObjects.assignAll(List<Map<String, dynamic>>.from(backendCategories));
          categories.assignAll(["All", ...backendCategories.map((c) => c['name'].toString())]);
          storage.write('categories_objects', categoriesObjects.toList());
          saveCategories();
        } catch (e) { print("Error fetching categories: $e"); }
      }(),

      // 3. Fetch Products
      () async {
        try {
          final backendProducts = await api.getProducts();
          List<FoodItem> parsedProducts = [];
          for (var p in backendProducts) {
            try { parsedProducts.add(FoodItem.fromJson(p)); } catch (e) {}
          }
          products.assignAll(parsedProducts);
          saveProducts();
        } catch (e) { print("Error fetching products: $e"); }
      }(),

      // 4. Fetch Prep Areas
      () async {
        try {
          final backendPrepAreas = await api.getPreparationAreas();
          preparationAreas.assignAll(backendPrepAreas.map((a) => PreparationAreaModel.fromJson(a)).toList());
          savePreparationAreas();
        } catch (e) { print("Error fetching preparation areas: $e"); }
      }(),

      // 5. Fetch Printers
      () async {
        try {
          final backendPrinters = await api.getPrinters();
          printers.assignAll(backendPrinters.map((p) => PrinterModel.fromJson(p)).toList());
          savePrinters();
        } catch (e) { print("Error fetching printers: $e"); }
      }(),

      // 6. Fetch Orders
      () async {
        try {
          final backendOrders = await api.getOrders();
          allOrders.assignAll(backendOrders.map((o) => normalizeOrder(o)).toList());
          saveAllOrders();
        } catch (e) { print("Error fetching orders: $e"); }
      }(),

      // 7. Fetch Tables
      () async {
        try {
          final backendAreas = await api.getTableAreas();
          if (backendAreas.isNotEmpty) {
            tableAreas.assignAll(backendAreas.map((a) => a['name'].toString()).toList());
            for (var a in backendAreas) {
              final String name = a['name'].toString();
              tableAreaBackendIds[name] = a['id'].toString();
              tableAreaDetails[name] = {
                "width_m": (a['width_m'] as num?)?.toDouble() ?? 10.0,
                "height_m": (a['height_m'] as num?)?.toDouble() ?? 10.0,
              };
            }
          }

          final backendTables = await api.getTables();
          if (backendTables.isNotEmpty || backendAreas.isNotEmpty) {
            Map<String, List<String>> tba = {};
            for (var area in tableAreas) { tba[area] = []; }

            for (var t in backendTables) {
              final String loc = t['area'] ?? t['location'] ?? "Zal"; 
              final String tableNum = t['number'] != null ? t['number'].toString() : "01";
              final String tableId = "$loc-$tableNum";

              if (!tba.containsKey(loc)) {
                tba[loc] = [];
                if (!tableAreas.contains(loc)) tableAreas.add(loc);
              }
              tba[loc]!.add(tableNum);
              tableBackendIds[tableId] = t['id'].toString();
              
              if (t['x'] != null && t['y'] != null) {
                tablePositions[tableId] = { "x": (t['x'] as num).toDouble(), "y": (t['y'] as num).toDouble() };
              }
              tableProperties[tableId] = {
                "width": (t['width'] as num?)?.toDouble() ?? 80.0,
                "height": (t['height'] as num?)?.toDouble() ?? 80.0,
                "shape": t['shape']?.toString() ?? "square",
              };
            }
            tablesByArea.assignAll(tba);
          }
        } catch (e) { print("Error fetching tables: $e"); }
      }(),

      // 8. Fetch Users
      () async {
        if (isAdmin || isCashier) {
          try {
            final backendUsers = await api.getUsers();
            users.assignAll(List<Map<String, dynamic>>.from(backendUsers));
            storage.write('all_users', users.toList());
          } catch (e) { print("Error fetching users: $e"); }
        }
      }(),
    ]);
  }

  Map<String, dynamic> normalizeOrder(Map<String, dynamic> o) {
    final tableNum = o['tableNumber'] ?? o['table_number'];
    final totalAmt = o['totalAmount'] ?? o['total_amount'];
    final typeStr = o['type'] ?? 'DINE_IN';
    final statusStr = o['status'] ?? 'PENDING';
    final timestamp = o['createdAt'] ?? o['created_at'];

    final List itemsList = o['items'] as List? ?? [];
    final Map<String, Map<String, dynamic>> groupedDetails = {};

    for (var i in itemsList) {
      final String id = (i['productId'] ?? i['product_id']).toString();
      final String name = i['product'] != null ? i['product']['name'] : (i['name'] ?? "Unknown");
      final int qty = (i['quantity'] ?? i['qty'] ?? 0) as int;
      final double price = double.tryParse((i['price'] ?? 0).toString()) ?? 0.0;

      if (groupedDetails.containsKey(id)) {
        groupedDetails[id]!['qty'] += qty;
      } else {
        groupedDetails[id] = {
          "id": id,
          "name": name,
          "qty": qty,
          "price": price,
        };
      }
    }

    final details = groupedDetails.values.toList();

    return {
      "id": o['id'],
      "table": tableNum != null ? tableNum.toString() : "-",
      "mode": typeStr.toString().toLowerCase().replaceAll("_", "-").capitalizeFirst,
      "items": details.fold(0, (sum, item) => sum + (item['qty'] as int)),
      "total": double.tryParse(totalAmt.toString()) ?? 0.0,
      "status": statusStr.toString().replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" "),
      "waiter_name": o['waiter_name'],
      "timestamp": timestamp,
      "details": details,
    };
  }

  void saveAllOrders() => storage.write('all_orders', allOrders.toList());
  void saveProducts() => storage.write('products', products.map((v) => v.toJson()).toList());
  void saveCategories() => storage.write('categories', categories.toList());
  void savePreparationAreas() => storage.write('preparation_areas', preparationAreas.map((v) => v.toJson()).toList());
  void savePrinters() => storage.write('printers', printers.map((v) => v.toJson()).toList());

  Future<void> updateCafeInfo({String? name, String? address, String? phone}) async {
    try {
      Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (address != null) data['address'] = address;
      if (phone != null) data['phone'] = phone;
      
      await api.updateCafe(cafeId, data);
      await fetchBackendData();
    } catch (e) {
      print("Error updating cafe info: $e");
      rethrow;
    }
  }

  void setupSocketListeners() {
    socket.onOrderStatusUpdated((data) {
      int index = allOrders.indexWhere((o) => o['id'] == data['orderId']);
      if (index != -1) {
        String rawStatus = data['status'].toString();
        allOrders[index]['status'] = rawStatus.replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" ");
        allOrders.refresh();
        saveAllOrders();
      }
    });

    socket.onTableLockStatus((data) {
      final String tableId = data['tableId'].toString();
      final String? userName = data['user'];
      if (userName != null) { lockedTables[tableId] = userName; } 
      else { lockedTables.remove(tableId); }
      lockedTables.refresh();
    });

    socket.onDataUpdated((data) {
      refreshData(showMessage: false);
    });
  }
}
