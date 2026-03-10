import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../../data/models/food_item.dart';
import '../../data/models/printer_model.dart';
import '../../data/models/preparation_area_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pos_controller_state.dart';

mixin DataSyncMixin on POSControllerState {
  Future<void> refreshData({bool showMessage = true}) async {
    if (!isOnline.value) {
      if (showMessage) Get.snackbar("Oflayn", "Internet yo'q, yangilab bo'lmaydi", 
        backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      await fetchBackendData();
      if (showMessage) {
        Get.snackbar("Yangilandi", "Ma'lumotlar muvaffaqiyatli yangilandi",
          backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
      }
    } catch (e) { print("Refresh error: $e"); }
  }

  void initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      ConnectivityResult result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      bool wasOffline = !isOnline.value;
      isOnline.value = result != ConnectivityResult.none;
      
      _handleConnectionOverlay();

      if (isOnline.value && wasOffline) {
        Get.snackbar("Onlayn", "Internet tiklandi. Sinxronizatsiya boshlandi...", 
          backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        processSyncQueue();
        refreshData(showMessage: false);
      } else if (!isOnline.value) {
        if (isOfflineSyncEnabled.value) {
          Get.snackbar("Oflayn", "Siz oflayn rejimda ishlayapsiz. Ma'lumotlar saqlab qo'yiladi.", 
            backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        } else {
          Get.snackbar("Oflayn", "Internet uzildi. Offline rejim o'chirilgan.", 
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        }
      }
    });

    // Check initial state
    _handleConnectionOverlay();

    // Load saved queue
    var savedQueue = storage.read('sync_queue');
    if (savedQueue != null) {
      syncQueue.assignAll(List<Map<String, dynamic>>.from(savedQueue));
      if (isOnline.value) processSyncQueue();
    }
  }

  void _handleConnectionOverlay() {
    if (!isOnline.value && !isOfflineSyncEnabled.value) {
      if (!Get.isDialogOpen!) {
        Get.dialog(
          WillPopScope(
            onWillPop: () async => false,
            child: Material(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 1)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.signal_wifi_off, size: 64, color: Colors.red),
                      const SizedBox(height: 24),
                      const Text(
                        "Internet yo'q",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Admin tomonidan oflayn ishlash o'chirilgan. Ilovadan foydalanish uchun internetga ulaning.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      const Text("Bog'lanish kutilmoqda...", style: TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );
      }
    } else {
      if (Get.isDialogOpen!) {
        // Only close if it's the connection dialog we opened.
        // Actually, to be safe, we close if it's open and we are online.
        Get.back(); 
      }
    }
  }

  bool addToSyncQueue(String type, Map<String, dynamic> data) {
    if (!isOfflineSyncEnabled.value) {
      Get.snackbar("Xato", "Offline ishlashga ruxsat yo'q. Internetni tekshiring.",
        backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    syncQueue.add({
      'id': uuid.v4(),
      'type': type,
      'data': data,
      'createdAt': DateTime.now().toIso8601String(),
    });
    storage.write('sync_queue', syncQueue.toList());
    return true;
  }

  Future<void> processSyncQueue() async {
    if (!isOnline.value || syncQueue.isEmpty) return;
    
    final List<Map<String, dynamic>> tasks = List.from(syncQueue);
    for (var task in tasks) {
      try {
        if (task['type'] == 'CREATE_ORDER') {
          await api.createOrder(task['data']);
        } else if (task['type'] == 'UPDATE_ORDER') {
          await api.updateOrder(task['data']['id'], task['data']['payload']);
        } else if (task['type'] == 'UPDATE_STATUS') {
          await api.updateOrderStatus(task['data']['id'], task['data']['status']);
        }
        
        syncQueue.removeWhere((t) => t['id'] == task['id']);
        storage.write('sync_queue', syncQueue.toList());
      } catch (e) {
        print("Sync task failed: $e");
        // If it's a permanent error (like 400), maybe remove it, but for now we keep trying
        if (e.toString().contains('400') || e.toString().contains('404')) {
           syncQueue.removeWhere((t) => t['id'] == task['id']);
           storage.write('sync_queue', syncQueue.toList());
        }
      }
    }
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
          instagramLink.value = cafe['instagram_link'] ?? "";
          telegramLink.value = cafe['telegram_link'] ?? "";
          showInstagramQr.value = cafe['show_instagram_qr'] ?? false;
          showPhoneOnReceipt.value = cafe['show_phone_on_receipt'] ?? true;
          allowWaiterMobileOrders.value = cafe['allow_waiter_mobile_orders'] ?? true;
          workStartTime.value = cafe['work_start_time'] ?? "00:00";
          workEndTime.value = cafe['work_end_time'] ?? "23:59";

          final rl = cafe['receipt_layout'];
          if (rl != null) receiptLayout.assignAll(List<Map<String, dynamic>>.from(rl));
          
          final krl = cafe['kitchen_receipt_layout'];
          if (krl != null) kitchenReceiptLayout.assignAll(List<Map<String, dynamic>>.from(krl));

          // Feature Flags
          isGeofencingEnabled.value = cafe['is_geofencing_enabled'] ?? true;
          isShiftBroadcastEnabled.value = cafe['is_shift_broadcast_enabled'] ?? true;
          isTableManagementEnabled.value = cafe['is_table_management_enabled'] ?? true;
          isKitchenPrintEnabled.value = cafe['is_kitchen_print_enabled'] ?? true;
          isSubscriptionEnforced.value = cafe['is_subscription_enforced'] ?? true;
          isQrLoginEnabled.value = cafe['is_qr_login_enabled'] ?? true;
          isOfflineSyncEnabled.value = cafe['is_offline_sync_enabled'] ?? true;
          isStockTrackingEnabled.value = cafe['is_stock_tracking_enabled'] ?? true;
          
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
          storage.write('instagram_link', instagramLink.value);
          storage.write('telegram_link', telegramLink.value);
          storage.write('allow_waiter_mobile_orders', allowWaiterMobileOrders.value);
          storage.write('work_start_time', workStartTime.value);
          storage.write('work_end_time', workEndTime.value);
          
          storage.write('receipt_layout', receiptLayout.toList());
          storage.write('kitchen_receipt_layout', kitchenReceiptLayout.toList());
          
          storage.write('is_geofencing_enabled', isGeofencingEnabled.value);
          storage.write('is_shift_broadcast_enabled', isShiftBroadcastEnabled.value);
          storage.write('is_table_management_enabled', isTableManagementEnabled.value);
          storage.write('is_kitchen_print_enabled', isKitchenPrintEnabled.value);
          storage.write('is_subscription_enforced', isSubscriptionEnforced.value);
          storage.write('is_qr_login_enabled', isQrLoginEnabled.value);
          storage.write('is_offline_sync_enabled', isOfflineSyncEnabled.value);
          storage.write('is_stock_tracking_enabled', isStockTrackingEnabled.value);
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
    try {
      final tableNum = o['tableNumber'] ?? o['table_number'];
      final tableArea = o['table_area'] ?? o['tableArea'];
      final totalAmt = o['totalAmount'] ?? o['total_amount'];
      final typeStr = o['type'] ?? 'DINE_IN';
      final statusStr = o['status'] ?? 'PENDING';
      final timestamp = o['createdAt'] ?? o['created_at'];

      final List itemsList = o['items'] is List ? o['items'] : (o['details'] is List ? o['details'] : []);
      final Map<String, Map<String, dynamic>> groupedDetails = {};

      for (var i in itemsList) {
        if (i is! Map) continue;
        final String id = (i['productId'] ?? i['product_id'] ?? i['id'] ?? "").toString();
        if (id.isEmpty) continue;
        
        final String? variantId = i['variant_id']?.toString();
        final String? variantName = i['variant_name']?.toString();
        
        // Try fallback to local catalog for "Unknown" products
        String name = i['product'] != null ? i['product']['name'] : (i['name'] ?? "Unknown");
        if ((name == "Unknown" || name.isEmpty) && id.isNotEmpty) {
           final catItem = products.firstWhereOrNull((p) => p.id.toString() == id);
           if (catItem != null) name = catItem.name;
        }

        final int qty = ((i['quantity'] ?? i['qty'] ?? 0) as num).toInt();
        final double price = double.tryParse((i['price'] ?? 0).toString()) ?? 0.0;
        final String? itemTime = i['createdAt'] ?? i['created_at'];

        // Filter out parent items that should have variants
        final catalogItem = products.firstWhereOrNull((p) => p.id.toString() == id);
        if (catalogItem != null && (catalogItem.hasVariants || catalogItem.variants.isNotEmpty) && variantId == null) {
          continue;
        }

        final String groupKey = variantId != null ? "${id}_$variantId" : id;

        if (groupedDetails.containsKey(groupKey)) {
          groupedDetails[groupKey]!['qty'] += qty;
        } else {
          groupedDetails[groupKey] = {
            "id": id,
            "variant_id": variantId,
            "variant_name": variantName,
            "name": (variantName != null && !name.contains("($variantName)")) 
                ? "$name ($variantName)" 
                : name,
            "qty": qty,
            "price": price,
            "timestamp": itemTime ?? timestamp,
          };
        }
      }

      final details = groupedDetails.values.toList();

      // ─── Professional ID-based table resolution ───────────────────────────
      String tableKey = "-";
      final String? tableUuid = o['table_id']?.toString();
      if (tableUuid != null && tableUuid.isNotEmpty) {
        final matchingEntry = tableBackendIds.entries.firstWhereOrNull(
          (e) => e.value == tableUuid,
        );
        tableKey = matchingEntry?.key ?? tableKey;
      } else if (tableNum != null) {
        final String rawNum = tableNum.toString();
        if (tableBackendIds.containsKey(rawNum)) {
          tableKey = rawNum;
        } else {
          final matchingEntry = tableBackendIds.entries.firstWhereOrNull((e) {
            final parts = e.key.split("-");
            return parts.length >= 2 && parts.sublist(1).join("-") == rawNum;
          });
          tableKey = matchingEntry?.key ?? rawNum;
        }
      }

      return {
        "id": o['id']?.toString(),
        "table": tableKey,
        "table_area": tableArea,
        "mode": typeStr.toString().toLowerCase().replaceAll("_", "-").capitalizeFirst,
        "items": details.fold(0, (sum, item) => sum + (item['qty'] as int)),
        "total": double.tryParse(totalAmt.toString()) ?? 0.0,
        "status": statusStr.toString().replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" "),
        "waiter_id": o['waiter_id']?.toString(),
        "waiter_name": o['waiter_name'],
        "timestamp": timestamp,
        "details": details,
        "discount_type": o['discount_type'],
        "discount_value": o['discount_value'],
        "discount_amount": o['discount_amount'],
        "service_fee_dine_in": o['service_fee_dine_in'],
        "service_fee_takeaway": o['service_fee_takeaway'],
        "service_fee_delivery": o['service_fee_delivery'],
      };
    } catch (e) {
      print("Error normalizing order: $e");
      return {
        "id": o['id']?.toString() ?? "0",
        "table": "-",
        "status": "Error",
        "items": 0,
        "total": 0.0,
        "details": [],
      };
    }
  }

  void saveAllOrders() => storage.write('all_orders', allOrders.toList());
  void saveProducts() => storage.write('products', products.map((v) => v.toJson()).toList());
  void saveCategories() => storage.write('categories', categories.toList());
  void savePreparationAreas() => storage.write('preparation_areas', preparationAreas.map((v) => v.toJson()).toList());
  void savePrinters() => storage.write('printers', printers.map((v) => v.toJson()).toList());

  Future<void> updateCafeInfo({
    String? name, 
    String? address, 
    String? phone, 
    String? instagramLink,
    String? telegramLink,
    Map<String, dynamic>? extraData
  }) async {
    try {
      Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (address != null) data['address'] = address;
      if (phone != null) data['phone'] = phone;
      if (instagramLink != null) data['instagram_link'] = instagramLink;
      if (telegramLink != null) data['telegram_link'] = telegramLink;
      if (extraData != null) data.addAll(extraData);
      
      await api.updateCafe(cafeId, data);
      await fetchBackendData();
    } catch (e) {
      print("Error updating cafe info: $e");
      rethrow;
    }
  }

  void setupSocketListeners() {
    socket.onOrderStatusUpdated((data) {
      int index = allOrders.indexWhere((o) => o['id']?.toString() == data['orderId']?.toString());
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
