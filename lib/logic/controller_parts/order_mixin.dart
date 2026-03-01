import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import 'pos_controller_state.dart';
import 'package:vibration/vibration.dart';

mixin OrderMixin on POSControllerState {
  double get subtotal => currentOrder.fold(0, (sum, item) {
    final foodItem = item['item'] as FoodItem;
    final variant = item['variant'] as FoodVariant?;
    final price = variant?.price ?? foodItem.price;
    return sum + (price * (item['quantity'] as int));
  });
  int get totalItems => currentOrder.fold(0, (sum, item) => sum + (item['quantity'] as int));
  bool get hasNewItems => currentOrder.any((item) => item['isNew'] == true && (item['quantity'] as int) > 0);
  bool get hasChanges => isOrderModified.value;

  double get serviceFee {
    if (currentMode.value == "Dine-in") {
      return subtotal * (serviceFeeDineIn.value / 100);
    } else if (currentMode.value == "Takeaway") {
      return serviceFeeTakeaway.value;
    } else if (currentMode.value == "Delivery") {
      return serviceFeeDelivery.value;
    }
    return 0.0;
  }

  double get total => subtotal + serviceFee;

  bool _checkGeofence() {
    bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!isWithinGeofence.value && isWaiter && !isDesktop) {
      Get.snackbar(
        "Hudud cheklovi", 
        "Siz kafe hududidan tashqaridasiz. Amallar bajarish cheklangan.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        icon: const Icon(Icons.location_off, color: Colors.white),
      );
      return false;
    }
    return true;
  }

  void addToCart(FoodItem item, {FoodVariant? variant}) {
    if (!_checkGeofence()) return;
    Vibration.vibrate(duration: 50, amplitude: 128);
    int index = currentOrder.indexWhere((e) => 
      e['item'].id == item.id && 
      e['variant']?.id == variant?.id &&
      e['isNew'] == true
    );
    if (index != -1) {
      currentOrder[index]['quantity']++;
    } else {
      currentOrder.add({
        'item': item, 
        'variant': variant,
        'quantity': 1, 
        'isNew': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void decrementFromCart(FoodItem item, {FoodVariant? variant}) {
    if (!_checkGeofence()) return;
    Vibration.vibrate(duration: 30, amplitude: 64);
    int index = currentOrder.indexWhere((e) => 
      e['item'].id == item.id && 
      e['variant']?.id == variant?.id &&
      e['isNew'] == true
    );
    if (index != -1) {
      if (currentOrder[index]['quantity'] > 1) {
        currentOrder[index]['quantity']--;
      } else {
        if (currentOrder[index]['isNew'] == false) {
          if (isWaiter) {
            Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni o'chira olmaydi", 
              backgroundColor: Colors.orange, colorText: Colors.white);
            return;
          }
          currentOrder[index]['quantity'] = 0;
        } else {
          currentOrder.removeAt(index);
        }
      }
      currentOrder.refresh();
      checkIfModified();
    }
  }

  void removeFromCart(int index) {
    if (currentOrder[index]['isNew'] == false) {
      if (isWaiter) {
        Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni o'chira olmaydi", 
          backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }
      currentOrder[index]['quantity'] = 0;
    } else {
      currentOrder.removeAt(index);
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void updateQuantity(int index, int delta) {
    if (!_checkGeofence()) return;
    int currentQty = currentOrder[index]['quantity'];
    int newQty = currentQty + delta;
    
    // Waiter restriction: cannot decrease sent items
    if (isWaiter && currentOrder[index]['isNew'] == false && delta < 0) {
      Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni kamaytira olmaydi", 
        backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (newQty > 0) {
      currentOrder[index]['quantity'] = newQty;
    } else {
      if (currentOrder[index]['isNew'] == false) {
        currentOrder[index]['quantity'] = 0;
      } else {
        currentOrder.removeAt(index);
      }
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void setAbsoluteQuantity(int index, int quantity) {
    int currentQty = currentOrder[index]['quantity'];
    
    // Waiter restriction: cannot decrease sent items
    if (isWaiter && currentOrder[index]['isNew'] == false && quantity < currentQty) {
      Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni kamaytira olmaydi", 
        backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (quantity > 0) {
      currentOrder[index]['quantity'] = quantity;
    } else {
      if (currentOrder[index]['isNew'] == false) {
        currentOrder[index]['quantity'] = 0;
      } else {
        currentOrder.removeAt(index);
      }
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void checkIfModified() {
    if (editingOrderId.value == null) {
      isOrderModified.value = currentOrder.isNotEmpty;
      return;
    }
    final currentJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "variant_id": (e['variant'] as FoodVariant?)?.id,
      "qty": e['quantity'],
    }).toList().toString();
    isOrderModified.value = currentJson != originalOrderJson;
  }

  Future<void> updateOrderStatus(dynamic orderId, String status) async {
    if (isOnline.value) {
      try {
        await api.updateOrderStatus(orderId, status);
      } catch (e) {
        print("Online status update failed: $e");
        addToSyncQueue('UPDATE_STATUS', {'id': orderId, 'status': status});
      }
    } else {
      addToSyncQueue('UPDATE_STATUS', {'id': orderId, 'status': status});
    }

    int index = allOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      allOrders[index]['status'] = status.toString().replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" ");
      allOrders.refresh();
      saveAllOrders();
    }
  }

  void deleteOrder(dynamic orderId) {
    allOrders.removeWhere((o) => o['id'] == orderId);
    printedKitchenQuantities.remove(orderId.toString());
    storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
    allOrders.refresh();
    saveAllOrders();
  }

  Future<void> changeOrderTable(dynamic orderId, String newTableId) async {
    try {
      await api.updateOrder(orderId, {"table_number": newTableId});
      int index = allOrders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        allOrders[index]['table'] = newTableId;
        allOrders.refresh();
        saveAllOrders();
      }
      Get.snackbar("Stol o'zgartirildi", "Buyurtma $newTableId-stolga o'tkazildi", 
        backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      print("Error updating table: $e");
      Get.snackbar("Xato", "Stolni o'zgartirishda xatolik yuz berdi", 
        backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void showQuantityDialog(int index) {
    final TextEditingController controller = TextEditingController(
      text: currentOrder[index]['quantity'].toString()
    );
    Get.dialog(
      AlertDialog(
        title: Text(currentOrder[index]['item'].name),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Miqdori"),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(controller.text);
              if (val != null) {
                setAbsoluteQuantity(index, val);
                Get.back();
              }
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  void clearCurrentOrder() {
    if (selectedTable.value.isNotEmpty) {
      socket.emitTableUnlock(selectedTable.value);
    }
    currentOrder.clear();
    selectedTable.value = "";
    editingOrderId.value = null;
    isOrderModified.value = false;
  }

  void loadOrderForEditing(Map<String, dynamic> order, List<FoodItem> catalog) {
    editingOrderId.value = order['id']?.toString();
    currentMode.value = order['mode'] ?? "Dine-in";
    final String tableVal = (order['table'] ?? "").toString();
    if (tableVal != "-" && tableVal.isNotEmpty) {
      selectedTable.value = tableVal.replaceFirst("Table ", "");
      socket.emitTableLock(selectedTable.value, currentUser.value?['name'] ?? "User");
    } else {
      selectedTable.value = "";
    }

    currentOrder.clear();
    final details = order['details'] as List? ?? [];
    for (var d in details) {
      final item = catalog.firstWhereOrNull((f) => f.id == d['id'] || f.name == d['name']);
      if (item != null) {
        FoodVariant? variant;
        if (d['variant_id'] != null && item.hasVariants) {
          variant = item.variants.firstWhereOrNull((v) => v.id == d['variant_id']);
        }
        
        currentOrder.add({
          'item': item, 
          'variant': variant,
          'quantity': d['qty'],
          'sentQty': d['qty'],
          'isNew': false,
          'timestamp': d['timestamp'] ?? order['timestamp'],
        });
      }
    }
    originalOrderJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "variant_id": (e['variant'] as FoodVariant?)?.id,
      "qty": e['quantity'],
    }).toList().toString();
    isOrderModified.value = false;

    // Sync printed quantities for kitchen
    final String orderIdStr = order['id'].toString();
    if (!printedKitchenQuantities.containsKey(orderIdStr)) {
      final Map<String, int> printedMap = {};
      for (var d in details) {
        printedMap[d['id'].toString()] = d['qty'] as int;
      }
      printedKitchenQuantities[orderIdStr] = printedMap;
      storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
    }
  }
}
