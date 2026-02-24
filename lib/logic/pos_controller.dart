import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io';
import '../data/models/food_item.dart';
import '../data/models/printer_model.dart';
import '../data/models/preparation_area_model.dart';
import 'controller_parts/pos_controller_state.dart';
import 'controller_parts/user_auth_mixin.dart';
import 'controller_parts/data_sync_mixin.dart';
import 'controller_parts/order_mixin.dart';
import 'controller_parts/printer_mixin.dart';
import 'controller_parts/product_mixin.dart';
import 'controller_parts/staff_mixin.dart';
import 'controller_parts/table_mixin.dart';
import 'package:audioplayers/audioplayers.dart';

class POSController extends POSControllerState with 
    UserAuthMixin, 
    DataSyncMixin, 
    OrderMixin, 
    PrinterMixin, 
    ProductMixin, 
    StaffMixin,
    TableMixin {

  @override
  void onInit() {
    super.onInit();
    _loadLocalData();
    fetchBackendData();
    _setupSocketListenersDetailed();
    updateService.checkForUpdate();
    startSubscriptionCheck();
    initLocationTracking();
  }

  @override
  void onClose() {
    subscriptionTimer?.cancel();
    locationTimer?.cancel();
    super.onClose();
  }

  void _loadLocalData() {
    var storedAllOrders = storage.read('all_orders');
    if (storedAllOrders != null) {
      allOrders.assignAll(List<Map<String, dynamic>>.from(storedAllOrders));
    }

    deviceRole.value = storage.read('device_role');
    waiterCafeId.value = storage.read('waiter_cafe_id');
    currentUser.value = storage.read('user');
    currentTerminal.value = storage.read('terminal');
    pinCode.value = storage.read('pin_code');

    var storedProducts = storage.read('products');
    if (storedProducts != null) {
      products.assignAll(List<Map<String, dynamic>>.from(storedProducts)
          .map((e) => FoodItem.fromJson(e)).toList());
    }

    var storedCategories = storage.read('categories_objects');
    if (storedCategories != null) {
      categoriesObjects.assignAll(List<Map<String, dynamic>>.from(storedCategories));
      categories.assignAll(["All", ...categoriesObjects.map((c) => c['name'].toString())]);
    }

    var storedPrepAreas = storage.read('preparation_areas');
    if (storedPrepAreas != null) {
      preparationAreas.assignAll(List<Map<String, dynamic>>.from(storedPrepAreas)
          .map((e) => PreparationAreaModel.fromJson(e)).toList());
    }

    var storedPrinters = storage.read('printers');
    if (storedPrinters != null) {
      printers.assignAll(List<Map<String, dynamic>>.from(storedPrinters)
          .map((e) => PrinterModel.fromJson(e)).toList());
    }

    var storedLocs = storage.read('table_positions');
    if (storedLocs != null) {
      try {
        Map<String, Map<String, double>> parsedLocs = {};
        (storedLocs as Map).forEach((key, value) {
          if (value is Map) {
            Map<String, double> coords = {};
            value.forEach((k, v) {
              coords[k.toString()] = (v as num).toDouble();
            });
            parsedLocs[key.toString()] = coords;
          }
        });
        tablePositions.assignAll(parsedLocs);
      } catch (e) {
        print("Error parsing table_positions: $e");
      }
    }

    if (currentUser.value != null) {
      socket.setCafeId(cafeId);
    }
  }

  void _setupSocketListenersDetailed() {
    setupSocketListeners();
    
    socket.onNewOrder((data) {
      int index = allOrders.indexWhere((o) => o['id'] == data['id']);
      if (index == -1) {
        final normalized = normalizeOrder(data);
        allOrders.insert(0, normalized);
        allOrders.refresh();
        saveAllOrders();

        if (isAdmin || isCashier) {
          printLocally(normalized, isKitchenOnly: true);
        }
      }
    });

    socket.onPrintRequest((data) async {
      if (isAdmin || isCashier) {
        final Map<String, dynamic> order = Map<String, dynamic>.from(data['order']);
        if (data['sender'] != null) order['waiter_name'] = data['sender'];
        final bool isKitchenOnly = data['isKitchenOnly'] == true;
        
        await printLocally(order, isKitchenOnly: isKitchenOnly, receiptTitle: data['receiptTitle']);
        
        // If it was a persistent job from DB, acknowledge it
        if (data['job_id'] != null) {
          socket.emitPrintAck(data['job_id']);
        }
      }
    });

    socket.onWaiterCall((data) {
      if (currentUser.value?['id']?.toString() == data['waiter_id'].toString()) {
        _playAlertSound();
        Get.snackbar("Chaqiruv!", "${data['sender_name']} sizni chaqirmoqda", 
          backgroundColor: Colors.red.withOpacity(0.9), 
          colorText: Colors.white, 
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });
  }

  Future<void> _playAlertSound() async {
    try {
      await audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
    } catch (e) {
      print("Error playing alert sound: $e");
    }
  }

  Future<bool> submitOrder({bool isPaid = false}) async {
    if (currentOrder.isEmpty) return false;
    bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!isWithinGeofence.value && isWaiter && !isDesktop) return false;

    if (editingOrderId.value != null) return await updateExistingOrder(isPaid: isPaid);

    final orderData = {
      "table_number": currentMode.value == "Dine-in" ? selectedTable.value : null,
      "type": currentMode.value.toUpperCase().replaceAll("-", "_"),
      "is_paid": isPaid,
      "waiter_name": selectedWaiter.value ?? currentUser.value?['name'],
      "cafe_id": cafeId,
      "items": currentOrder.map((e) => {
        "product_id": (e['item'] as FoodItem).id,
        "quantity": e['quantity'],
        "price": (e['item'] as FoodItem).price
      }).toList(),
    };

    try {
      final newOrder = await api.createOrder(orderData);
      final normalized = normalizeOrder(newOrder);
      allOrders.insert(0, normalized);
      
      await printOrder(normalized, isKitchenOnly: !isPaid, 
        receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI");

      clearCurrentOrder();
      saveAllOrders();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateExistingOrder({bool isPaid = false}) async {
    if (editingOrderId.value == null) return false;
    bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!isWithinGeofence.value && isWaiter && !isDesktop) return false;
    
    try {
      final newStatus = isPaid ? "Completed" : "Preparing";
      Map<dynamic, Map<String, dynamic>> aggregated = {};
      for (var e in currentOrder) {
        final item = e['item'] as FoodItem;
        if (aggregated.containsKey(item.id)) { aggregated[item.id]!['qty'] += e['quantity']; } 
        else {
          aggregated[item.id] = { "id": item.id, "product_id": item.id, "name": item.name, "qty": e['quantity'], "quantity": e['quantity'], "price": item.price };
        }
      }
      final consolidatedList = aggregated.values.toList();

      await api.updateOrderStatus(editingOrderId.value!, newStatus);
      await api.updateOrder(editingOrderId.value!, {
        "items": consolidatedList.map((i) => { "product_id": i["id"], "quantity": i["qty"], "price": i["price"] }).toList()
      });
      
      int index = allOrders.indexWhere((o) => o['id'] == editingOrderId.value);
      if (index != -1) {
        allOrders[index]['items'] = totalItems;
        allOrders[index]['total'] = total;
        allOrders[index]['status'] = newStatus;
        allOrders[index]['mode'] = currentMode.value;
        allOrders[index]['table'] = currentMode.value == "Dine-in" ? selectedTable.value : "-";
        allOrders[index]['details'] = consolidatedList;
        
        await printOrder(allOrders[index], isKitchenOnly: !isPaid, 
          receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI");

        allOrders.refresh();
        clearCurrentOrder();
        saveAllOrders();
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  void setMode(String mode) => currentMode.value = mode;
  void setTable(String table) {
    if (selectedTable.value.isNotEmpty) socket.emitTableUnlock(selectedTable.value);
    selectedTable.value = table;
    if (table.isNotEmpty) socket.emitTableLock(table, currentUser.value?['name'] ?? "User");
  }
  void toggleEditMode() => isEditMode.value = !isEditMode.value;
  void setDeviceRole(String? role) { deviceRole.value = role; storage.write('device_role', role); }
  void setWaiterCafeId(String? cafeId) { waiterCafeId.value = cafeId; storage.write('waiter_cafe_id', cafeId); }
}
