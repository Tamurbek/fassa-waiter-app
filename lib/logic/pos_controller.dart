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
import 'package:vibration/vibration.dart';

class POSController extends POSControllerState with 
    UserAuthMixin, 
    DataSyncMixin, 
    OrderMixin, 
    PrinterMixin, 
    ProductMixin, 
    StaffMixin,
    TableMixin {

  final Map<String, DateTime> _processedPrintIds = {};

  @override
  void onInit() {
    super.onInit();
    _loadLocalData();
    initConnectivityListener();
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

    var storedPrinted = storage.read('printed_kitchen_items');
    if (storedPrinted != null) {
      try {
        Map<String, Map<String, int>> parsed = {};
        (storedPrinted as Map).forEach((orderId, items) {
          if (items is Map) {
            Map<String, int> itemMap = {};
            items.forEach((pId, qty) {
              itemMap[pId.toString()] = (qty as num).toInt();
            });
            parsed[orderId.toString()] = itemMap;
          }
        });
        printedKitchenQuantities.assignAll(parsed);
      } catch (e) { print("Error parsing printed_kitchen_items: $e"); }
    }

    if (currentUser.value != null || currentTerminal.value != null) {
      socket.setCafeId(cafeId);
    }

    // Load Printer Settings
    printerPaperSize.value = storage.read('printer_paper_size') ?? "80mm";
    autoPrintReceipt.value = storage.read('auto_print_receipt') ?? false;
    enableKitchenPrint.value = storage.read('enable_kitchen_print') ?? true;
    enableBillPrint.value = storage.read('enable_bill_print') ?? true;
    enablePaymentPrint.value = storage.read('enable_payment_print') ?? true;

    // Load Feature Flags
    isGeofencingEnabled.value = storage.read('is_geofencing_enabled') ?? true;
    isShiftBroadcastEnabled.value = storage.read('is_shift_broadcast_enabled') ?? true;
    isTableManagementEnabled.value = storage.read('is_table_management_enabled') ?? true;
    isKitchenPrintEnabled.value = storage.read('is_kitchen_print_enabled') ?? true;
    isSubscriptionEnforced.value = storage.read('is_subscription_enforced') ?? true;
    isQrLoginEnabled.value = storage.read('is_qr_login_enabled') ?? true;
    isOfflineSyncEnabled.value = storage.read('is_offline_sync_enabled') ?? true;
    isStockTrackingEnabled.value = storage.read('is_stock_tracking_enabled') ?? true;

    // Load Cafe Settings (Offline/First-load)
    restaurantName.value = storage.read('restaurant_name') ?? "";
    restaurantAddress.value = storage.read('restaurant_address') ?? "";
    restaurantPhone.value = storage.read('restaurant_phone') ?? "";
    currency.value = storage.read('currency') ?? "UZS";
    serviceFeeDineIn.value = (storage.read('service_fee_dine_in') as num?)?.toDouble() ?? 10.0;
    serviceFeeTakeaway.value = (storage.read('service_fee_takeaway') as num?)?.toDouble() ?? 0.0;
    serviceFeeDelivery.value = (storage.read('service_fee_delivery') as num?)?.toDouble() ?? 3000.0;
    receiptHeader.value = storage.read('receipt_header') ?? "";
    receiptFooter.value = storage.read('receipt_footer') ?? "Xaridingiz uchun rahmat!";
    showLogo.value = storage.read('show_logo') ?? true;
    instagramLink.value = storage.read('instagram_link') ?? "";
    telegramLink.value = storage.read('telegram_link') ?? "";
  }

  void _setupSocketListenersDetailed() {
    setupSocketListeners();
    
    socket.onNewOrder((data) {
      int index = allOrders.indexWhere((o) => o['id'].toString() == data['id'].toString());
      if (index == -1) {
        final normalized = normalizeOrder(data);
        allOrders.insert(0, normalized);
        allOrders.refresh();
        saveAllOrders();

        if (isAdmin || isCashier) {
          final orderId = data['id']?.toString();
          if (orderId != null) {
            final now = DateTime.now();
            final printKey = "${orderId}_kitchen_auto";
            if (_processedPrintIds.containsKey(printKey) && 
                now.difference(_processedPrintIds[printKey]!).inSeconds < 10) {
              return;
            }
            _processedPrintIds[printKey] = now;
          }
          printLocally(normalized, isKitchenOnly: true);
        }
      }
    });

    socket.onPrintRequest((data) async {
      if (isAdmin || isCashier) {
        final orderId = data['order']?['id']?.toString();
        final String receiptTitle = data['receiptTitle']?.toString() ?? (data['isKitchenOnly'] == true ? "KITCHEN" : "ALL");

        if (orderId != null) {
          final now = DateTime.now();
          final printKey = "${orderId}_$receiptTitle";
          if (_processedPrintIds.containsKey(printKey) && 
              now.difference(_processedPrintIds[printKey]!).inSeconds < 10) {
            return;
          }
          _processedPrintIds[printKey] = now;
        }

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

    socket.onWaiterCall((data) async {
      if (currentUser.value?['id']?.toString() == data['waiter_id'].toString()) {
        _playAlertSound();
        
        // Vibrate if supported
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 2000, amplitude: 255);
        }

        Get.snackbar("Chaqiruv!", "${data['sender_name']} sizni chaqirmoqda", 
          backgroundColor: Colors.red.withOpacity(0.9), 
          colorText: Colors.white, 
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });

    socket.onForceLogoutUser((data) {
      if (currentUser.value != null && 
          currentUser.value!['id'].toString() == data['user_id'].toString() &&
          currentUser.value!['session_id'] != null &&
          currentUser.value!['session_id'].toString() != data['session_id'].toString()) {
        Get.snackbar("Tizimdan chiqildi", "Sizning hisobingiz boshqa qurilmadan ochildi.",
          backgroundColor: Colors.red, colorText: Colors.white, duration: const Duration(seconds: 5));
        logout(forced: true);
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
    if (isSubmitting.value) return false;
    if (currentOrder.isEmpty) {
      Get.snackbar("Xato", "Savat bo'sh", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
    isSubmitting.value = true;
    try {
      bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      
      if (!isWithinGeofence.value && isWaiter && !isDesktop) {
        Get.snackbar("Xato", "Buyurtma berish uchun kafe hududida bo'lishingiz kerak.", 
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        isSubmitting.value = false;
        return false;
      }

      if (editingOrderId.value != null) return await updateExistingOrder(isPaid: isPaid);

      if (!isOnline.value && !isOfflineSyncEnabled.value) {
        Get.snackbar("Xato", "Internetingiz o'chgan va oflayn rejim ruxsat etilmagan. Buyurtmani faqat onlayn holatda berish mumkin.",
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        return false;
      }

      final orderData = {
        "id": uuid.v4(), // Client-side ID for offline sync
        "table_number": currentMode.value == "Dine-in" ? selectedTable.value : null,
        "type": currentMode.value.toUpperCase().replaceAll("-", "_"),
        "is_paid": isPaid,
        "waiter_name": selectedWaiter.value ?? currentUser.value?['name'],
        "cafe_id": cafeId,
        "createdAt": DateTime.now().toIso8601String(),
        "total_amount": total,
        "items": () {
          final Map<String, Map<String, dynamic>> grouped = {};
          for (var e in currentOrder) {
            final FoodItem item = e['item'] as FoodItem;
            final FoodVariant? variant = e['variant'] as FoodVariant?;
            final String id = item.id.toString();
            final String? variantId = variant?.id;
            final String groupKey = variantId != null ? "${id}_$variantId" : id;
            final int qty = e['quantity'] as int;
            if (qty <= 0) continue;

            if (grouped.containsKey(groupKey)) {
              grouped[groupKey]!['quantity'] += qty;
            } else {
              grouped[groupKey] = {
                "product_id": id,
                "variant_id": variantId,
                "variant_name": variant?.name,
                "quantity": qty,
                "price": variant?.price ?? item.price
              };
            }
          }
          return grouped.values.toList();
        }(),
      };

      final normalized = normalizeOrder(orderData);

      if (isOnline.value) {
        try {
          allOrders.insert(0, normalized);
          allOrders.refresh();
          saveAllOrders();

          final newOrder = await api.createOrder(orderData);
          int idx = allOrders.indexWhere((o) => o['id'] == normalized['id']);
          if (idx != -1) {
            allOrders[idx] = normalizeOrder(newOrder);
            allOrders.refresh();
            saveAllOrders();
          }
        } catch (e) {
          print("Online order failed: $e");
          if (isOfflineSyncEnabled.value) {
            addToSyncQueue('CREATE_ORDER', orderData);
          } else {
            allOrders.removeWhere((o) => o['id'] == orderData['id']);
            allOrders.refresh();
            saveAllOrders();
            Get.snackbar("Xato", "Buyurtmani yuborishda xatolik yuz berdi. Offline rejim ochiq emas.",
                backgroundColor: Colors.red, colorText: Colors.white);
            return false;
          }
        }
      } else {
        allOrders.insert(0, normalized);
        allOrders.refresh();
        saveAllOrders();
        
        addToSyncQueue('CREATE_ORDER', orderData);
        Get.snackbar("Oflayn", "Buyurtma saqlandi. Internet paydo bo'lishi bilan yuboriladi.", 
          backgroundColor: Colors.blue, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      }

      await printOrder(normalized, isKitchenOnly: !isPaid, 
          receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI");

      clearCurrentOrder();
      return true;
    } catch (e) {
      Get.snackbar("Xato", "Buyurtmani saqlashda xatolik yuz berdi: $e", 
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  Future<bool> updateExistingOrder({bool isPaid = false}) async {
    if (editingOrderId.value == null) return false;
    try {
      bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      
      if (!isWithinGeofence.value && isWaiter && !isDesktop) {
        Get.snackbar("Xato", "O'zgarishlarni saqlash uchun kafe hududida bo'lishingiz kerak.", 
            backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        isSubmitting.value = false;
        return false;
      }
      final newStatus = isPaid ? "Completed" : "Preparing";
      List<Map<String, dynamic>> consolidatedList = [];
      List<Map<String, dynamic>> cancelledItems = [];
      final Map<String, Map<String, dynamic>> grouped = {};
      final Map<String, int> totalSentQty = {};

      final Map<String, String> groupKeyToName = {};

      for (var e in currentOrder) {
        final item = e['item'] as FoodItem;
        final FoodVariant? variant = e['variant'] as FoodVariant?;
        final String id = item.id.toString();
        final String? variantId = variant?.id;
        final String groupKey = variantId != null ? "${id}_$variantId" : id;
        final int qty = e['quantity'];
        final int sentQty = e['sentQty'] ?? 0;

        groupKeyToName[groupKey] = variant != null ? "${item.name} (${variant.name})" : item.name;
        totalSentQty[groupKey] = (totalSentQty[groupKey] ?? 0) + sentQty;

        if (qty > 0) {
          if (grouped.containsKey(groupKey)) {
            grouped[groupKey]!['qty'] += qty;
            grouped[groupKey]!['quantity'] += qty;
          } else {
            grouped[groupKey] = {
              "id": id,
              "product_id": id,
              "variant_id": variantId,
              "variant_name": variant?.name,
              "name": variant != null ? "${item.name} (${variant.name})" : item.name,
              "qty": qty,
              "quantity": qty,
              "price": variant?.price ?? item.price,
            };
          }
        }
      }

      consolidatedList = grouped.values.toList();

      // track cancellations for receipt display
      totalSentQty.forEach((groupKey, sentQty) {
        final int currentQty = grouped[groupKey]?['qty'] ?? 0;
        if (currentQty < sentQty) {
          cancelledItems.add({
            "id": groupKey,
            "name": groupKeyToName[groupKey] ?? "Unknown",
            "qty": sentQty - currentQty,
          });
        }
      });

      consolidatedList = grouped.values.toList();

      final payload = {
        "items": consolidatedList.map((i) => { "product_id": i["id"], "variant_id": i["variant_id"], "variant_name": i["variant_name"], "quantity": i["qty"], "price": i["price"] }).toList()
      };

      if (isOnline.value) {
        try {
          await api.updateOrderStatus(editingOrderId.value!, newStatus);
          await api.updateOrder(editingOrderId.value!, payload);
        } catch (e) {
          print("Online update failed, task added to sync queue: $e");
          if (!addToSyncQueue('UPDATE_STATUS', {'id': editingOrderId.value!, 'status': newStatus})) return false;
          addToSyncQueue('UPDATE_ORDER', {'id': editingOrderId.value!, 'payload': payload});
        }
      } else {
          if (!addToSyncQueue('UPDATE_STATUS', {'id': editingOrderId.value!, 'status': newStatus})) return false;
          addToSyncQueue('UPDATE_ORDER', {'id': editingOrderId.value!, 'payload': payload});
      }
      
      int index = allOrders.indexWhere((o) => o['id'].toString() == editingOrderId.value.toString());
      if (index != -1) {
        final orderToPrint = Map<String, dynamic>.from(allOrders[index]);
        orderToPrint['items'] = totalItems;
        orderToPrint['total'] = total;
        orderToPrint['status'] = newStatus;
        orderToPrint['mode'] = currentMode.value;
        orderToPrint['table'] = currentMode.value == "Dine-in" ? selectedTable.value : "-";
        orderToPrint['details'] = consolidatedList;
        orderToPrint['cancelled_items'] = cancelledItems; // Pass to printer
        
        // Update allOrders with new details
        allOrders[index] = orderToPrint;

        final orderId = editingOrderId.value?.toString();
        if (orderId != null) {
          _processedPrintIds[orderId] = DateTime.now();
        }

        await printOrder(orderToPrint, isKitchenOnly: !isPaid, 
            receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI");

        allOrders.refresh();
        clearCurrentOrder();
        saveAllOrders();
        return true;
      }
      
      Get.snackbar("Xatolik", "Buyurtma topilmadi. Iltimos, ma'lumotlarni yangilang.", 
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false;
    } catch (e) { 
      Get.snackbar("Xato", "O'zgarishlarni saqlashda xatolik: $e", 
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return false; 
    }
  }

  void setTable(String table) {
    if (table.isNotEmpty) {
      bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      if (!isWithinGeofence.value && isWaiter && !isDesktop) {
        Get.snackbar(
          "Hudud cheklovi", 
          "Stol tanlash uchun kafe hududida bo'lishingiz kerak.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    }
    
    editingOrderId.value = null; // Ensure we're not in edit mode for a new table
    isOrderModified.value = false;
    currentOrder.clear(); // Clear any previous cart content
    
    if (selectedTable.value.isNotEmpty) socket.emitTableUnlock(selectedTable.value);
    selectedTable.value = table;
    if (table.isNotEmpty) socket.emitTableLock(table, currentUser.value?['name'] ?? "User");
  }
  void setMode(String mode) => currentMode.value = mode;
  void toggleEditMode() => isEditMode.value = !isEditMode.value;
  void setDeviceRole(String? role) { deviceRole.value = role; storage.write('device_role', role); }
  void setWaiterCafeId(String? cafeId) { waiterCafeId.value = cafeId; storage.write('waiter_cafe_id', cafeId); }
}
