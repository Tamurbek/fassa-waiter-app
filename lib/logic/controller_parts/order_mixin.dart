import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import 'pos_controller_state.dart';

mixin OrderMixin on POSControllerState {
  double get subtotal => currentOrder.fold(0, (sum, item) => sum + ((item['item'] as FoodItem).price * (item['quantity'] as int)));
  int get totalItems => currentOrder.fold(0, (sum, item) => sum + (item['quantity'] as int));
  bool get hasNewItems => currentOrder.any((item) => item['isNew'] == true && (item['quantity'] as int) > 0);

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

  void addToCart(FoodItem item) {
    int index = currentOrder.indexWhere((e) => e['item'].id == item.id && e['isNew'] == true);
    if (index != -1) {
      currentOrder[index]['quantity']++;
    } else {
      currentOrder.add({'item': item, 'quantity': 1, 'isNew': true});
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void decrementFromCart(FoodItem item) {
    int index = currentOrder.indexWhere((e) => e['item'].id == item.id && e['isNew'] == true);
    if (index != -1) {
      if (currentOrder[index]['quantity'] > 1) {
        currentOrder[index]['quantity']--;
      } else {
        currentOrder.removeAt(index);
      }
      currentOrder.refresh();
      checkIfModified();
    }
  }

  void removeFromCart(int index) {
    currentOrder.removeAt(index);
    currentOrder.refresh();
    checkIfModified();
  }

  void updateQuantity(int index, int delta) {
    int newQty = (currentOrder[index]['quantity'] as int) + delta;
    if (newQty > 0) {
      currentOrder[index]['quantity'] = newQty;
    } else {
      currentOrder.removeAt(index);
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void setAbsoluteQuantity(int index, int quantity) {
    if (quantity > 0) {
      currentOrder[index]['quantity'] = quantity;
    } else {
      currentOrder.removeAt(index);
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
      "qty": e['quantity'],
    }).toList().toString();
    isOrderModified.value = currentJson != originalOrderJson;
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      await api.updateOrderStatus(orderId, status);
      int index = allOrders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        allOrders[index]['status'] = status.toString().replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" ");
        allOrders.refresh();
        saveAllOrders();
      }
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  void deleteOrder(int orderId) {
    allOrders.removeWhere((o) => o['id'] == orderId);
    printedKitchenQuantities.remove(orderId.toString());
    storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
    allOrders.refresh();
    saveAllOrders();
  }

  Future<void> changeOrderTable(int orderId, String newTableId) async {
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
    editingOrderId.value = order['id'];
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
        currentOrder.add({
          'item': item, 
          'quantity': d['qty'],
          'sentQty': d['qty'],
          'isNew': false,
        });
      }
    }
    originalOrderJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "qty": e['quantity'],
    }).toList().toString();
    isOrderModified.value = false;
  }
}
