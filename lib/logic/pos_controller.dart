import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';
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
import '../theme/app_theme.dart';
import '../presentation/pages/main_navigation_screen.dart';

class POSController extends POSControllerState with 
    UserAuthMixin, 
    DataSyncMixin, 
    OrderMixin, 
    PrinterMixin, 
    ProductMixin, 
    StaffMixin,
    TableMixin {


  // processedPrintIds is now in POSControllerState

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
      if (currentUser.value == null && currentTerminal.value != null) {
        api.restoreTerminalToken();
      }
      socket.setCafeId(cafeId);
    }

    // Load Printer Settings
    printerPaperSize.value = storage.read('printer_paper_size') ?? "80mm";
    autoPrintReceipt.value = storage.read('auto_print_receipt') ?? false;
    enableKitchenPrint.value = storage.read('enable_kitchen_print') ?? true;
    enableBillPrint.value = storage.read('enable_bill_print') ?? true;
    enablePaymentPrint.value = storage.read('enable_payment_print') ?? true;
    isDarkMode.value = storage.read('is_dark_mode') ?? false;
    isFullScreen.value = storage.read('is_full_screen') ?? false;
    isAutoStart.value = storage.read('is_auto_start') ?? false;
    
    if (isDarkMode.value) {
      Get.changeTheme(AppTheme.darkTheme);
    }

    if (isFullScreen.value) {
      _applyFullScreen(true);
    }

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
    restaurantName.value = (storage.read('restaurant_name') ?? "").toString();
    restaurantAddress.value = (storage.read('restaurant_address') ?? "").toString();
    restaurantPhone.value = (storage.read('restaurant_phone') ?? "").toString();
    currency.value = (storage.read('currency') ?? "UZS").toString();
    
    try {
      serviceFeeDineIn.value = double.tryParse(storage.read('service_fee_dine_in')?.toString() ?? "") ?? 10.0;
      serviceFeeTakeaway.value = double.tryParse(storage.read('service_fee_takeaway')?.toString() ?? "") ?? 0.0;
      serviceFeeDelivery.value = double.tryParse(storage.read('service_fee_delivery')?.toString() ?? "") ?? 3000.0;
    } catch (e) { print("Error parsing service fees: $e"); }
    receiptHeader.value = storage.read('receipt_header') ?? "";
    receiptFooter.value = storage.read('receipt_footer') ?? "Xaridingiz uchun rahmat!";
    showLogo.value = storage.read('show_logo') ?? true;
    instagramLink.value = storage.read('instagram_link') ?? "";
    telegramLink.value = storage.read('telegram_link') ?? "";
    
    var rl = storage.read('receipt_layout');
    if (rl != null) receiptLayout.assignAll(List<Map<String, dynamic>>.from(rl));
    
    var krl = storage.read('kitchen_receipt_layout');
    if (krl != null) kitchenReceiptLayout.assignAll(List<Map<String, dynamic>>.from(krl));
  }

  void _setupSocketListenersDetailed() {
    setupSocketListeners();
    
    socket.onOrderStatusUpdated((data) {
      final orderId = data['orderId']?.toString();
      final status = data['status']?.toString().toUpperCase();
      
      int index = allOrders.indexWhere((o) => o['id']?.toString() == orderId);
      if (index != -1) {
        final order = allOrders[index];
        final String oldStatus = order['status']?.toString() ?? "";
        final String rawStatus = status ?? "PENDING";
        final String newStatusFormatted = rawStatus.replaceAll("_", " ")
            .split(" ")
            .map((s) => s.isNotEmpty ? s.toLowerCase().capitalizeFirst : "")
            .join(" ");
        
        allOrders[index]['status'] = newStatusFormatted;
        allOrders.refresh();
        saveAllOrders();

        // Faqat "READY" bo'lganda va avval tayyor bo'lmagan bo'lsa xabar berish
        if (status == "READY" && !oldStatus.toLowerCase().contains("ready")) {
           bool isMyOrder = order['waiter_name'] == currentUser.value?['name'];
           
           // Ofitsiantga faqat o'zini buyurtmasi, Admin/Kassirga barchasi
           if (isMyOrder || isAdmin || isCashier) {
              _playReadySound();
              
              if (isMyOrder && (Platform.isAndroid || Platform.isIOS)) {
                Vibration.vibrate(duration: 500);
              }
              
              Get.snackbar(
                "Buyurtma tayyor!",
                "Stol: ${order['table']} buyurtmasi tayyor bo'ldi.",
                snackPosition: SnackPosition.TOP,
                backgroundColor: isMyOrder ? Colors.green.withOpacity(0.9) : Colors.blue.withOpacity(0.8),
                colorText: Colors.white,
                duration: const Duration(seconds: 4),
                margin: const EdgeInsets.all(10),
                borderRadius: 15,
                icon: const Icon(Icons.check_circle, color: Colors.white),
              );
           }
        }
      }
    });

    socket.onNewOrder((data) {
      final String? clientId = data['client_id']?.toString();
      final String? serverId = data['id']?.toString();
      
      int index = allOrders.indexWhere((o) => 
          (clientId != null && o['id'].toString() == clientId) || 
          (serverId != null && o['id'].toString() == serverId));
          
      if (index == -1) {
        final normalized = normalizeOrder(data);
        allOrders.insert(0, normalized);
        allOrders.refresh();
        saveAllOrders();

        if (isAdmin || isCashier) {
            final now = DateTime.now();
            final printKeyKitchen = "${serverId ?? clientId}_kitchen";
            
            // Check BOTH server id and client uuid for deduplication
            bool isAlreadyDone = processedPrintIds.containsKey(printKeyKitchen) && 
                                now.difference(processedPrintIds[printKeyKitchen]!).inSeconds < 15;
            
            if (!isAlreadyDone && clientId != null) {
              final uuidKey = "${clientId}_kitchen";
              if (processedPrintIds.containsKey(uuidKey) && 
                  now.difference(processedPrintIds[uuidKey]!).inSeconds < 15) {
                isAlreadyDone = true;
              }
            }
            
            if (isAlreadyDone) return;
            
            // Mark as processed
            if (serverId != null) processedPrintIds["${serverId}_kitchen"] = now;
            if (clientId != null) processedPrintIds["${clientId}_kitchen"] = now;
            
            printLocally(normalized, isKitchenOnly: true);
        }
      } else {
         if (clientId != null && serverId != null) {
            int uuidIdx = allOrders.indexWhere((o) => o['id'].toString() == clientId);
            if (uuidIdx != -1) {
               allOrders[uuidIdx]['id'] = serverId;
               allOrders.refresh();
            }
         }
      }
    });

    socket.onPrintRequest((data) async {
      if (isAdmin || isCashier) {
        final orderId = data['order']?['id']?.toString();
        final clientId = data['order']?['client_id']?.toString();
        final String receiptTitle = data['receiptTitle']?.toString() ?? (data['isKitchenOnly'] == true ? "kitchen" : "all");
        final String lowerTitle = receiptTitle.toLowerCase();
        
        if (orderId != null || clientId != null) {
          final now = DateTime.now();
          bool isAlreadyDone = false;
          
          if (orderId != null) {
            final printKey = "${orderId}_$lowerTitle";
            if (processedPrintIds.containsKey(printKey) && 
                now.difference(processedPrintIds[printKey]!).inSeconds < 10) {
              isAlreadyDone = true;
            }
          }
          
          if (!isAlreadyDone && clientId != null) {
            final printKey = "${clientId}_$lowerTitle";
            if (processedPrintIds.containsKey(printKey) && 
                now.difference(processedPrintIds[printKey]!).inSeconds < 10) {
              isAlreadyDone = true;
            }
          }

          if (isAlreadyDone) return;
          
          // Mark as processed
          if (orderId != null) processedPrintIds["${orderId}_$lowerTitle"] = now;
          if (clientId != null) processedPrintIds["${clientId}_$lowerTitle"] = now;
        }

        final Map<String, dynamic> order = Map<String, dynamic>.from(data['order']);
        if (data['sender'] != null) order['waiter_name'] = data['sender'];
        final bool isKitchenOnly = data['isKitchenOnly'] == true;
        
        await printLocally(order, isKitchenOnly: isKitchenOnly, receiptTitle: data['receiptTitle']);
        
        if (data['job_id'] != null) {
          socket.emitPrintAck(data['job_id']);
        }
      }
    });

    socket.onWaiterCall((data) async {
      if (currentUser.value?['id']?.toString() == data['waiter_id'].toString()) {
        _playAlertSound();
        
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

    socket.onForceLogoutSession((data) {
      if (currentUser.value != null && 
          currentUser.value!['session_id'] != null &&
          currentUser.value!['session_id'].toString() == data['session_id'].toString()) {
        logout(forced: true);
        Get.snackbar("Tizimdan chiqildingiz", "Administrator ushbu qurilmada sessiyani yopdi.",
          backgroundColor: Colors.red, colorText: Colors.white, duration: const Duration(seconds: 5));
      }
    });

    socket.onForceLogoutTerminal((data) {
      if (currentTerminal.value != null && data['terminal_id'] == currentTerminal.value!['id'].toString()) {
        if (data['login_instance_id'] != currentTerminal.value!['login_instance_id']) {
          logout(forced: true);
          Get.snackbar("Sessiya tugadi", "Ushbu terminal boshqa qurilmada ochilganligi sabab tizimdan chiqdingiz.", 
            backgroundColor: Colors.red, colorText: Colors.white);
        }
      }
    });

    socket.onForceLogoutUser((data) {
      if (currentUser.value != null && 
          currentUser.value!['id'].toString() == data['user_id'].toString() &&
          currentUser.value!['session_id'] != null &&
          currentUser.value!['session_id'].toString() != data['session_id'].toString()) {
        logout(forced: true);
        Get.snackbar("Tizimdan chiqildi", "Sizning hisobingiz boshqa qurilmada ochildi.",
          backgroundColor: Colors.red, colorText: Colors.white, duration: const Duration(seconds: 5));
      }
    });

    socket.onForceLogout((data) {
      if (currentUser.value != null) {
        final List<dynamic> userIds = data['user_ids'] ?? [];
        if (userIds.contains(currentUser.value!['id'].toString())) {
          logout(forced: true);
          Get.snackbar(
            "Tizimdan chiqarildingiz", 
            "Administrator sizni barcha qurilmalardan chiqardi.", 
            backgroundColor: Colors.red, 
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    });
  }

  Future<void> _playReadySound() async {
    try {
      // Subtle "ding" for ready status
      await audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2358/2358-preview.mp3'));
    } catch (e) {
      print("Error playing ready sound: $e");
    }
  }

  Future<void> _playAlertSound() async {
    try {
      await audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2358/2358-preview-mp3'));
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

      final String orderId = uuid.v4();
      final orderData = {
        "id": orderId,
        "table_id": currentMode.value == "Dine-in" ? tableBackendIds[selectedTable.value] : null,
        "table_number": currentMode.value == "Dine-in" ? selectedTable.value : null,
        "type": currentMode.value.toUpperCase().replaceAll("-", "_"),
        "is_paid": isPaid,
        "waiter_id": selectedWaiterId.value ?? currentUser.value?['id']?.toString(),
        "waiter_name": selectedWaiter.value ?? currentUser.value?['name'],
        "cafe_id": cafeId,
        "createdAt": DateTime.now().toIso8601String(),
        "total_amount": total,
        "client_id": orderId,
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

            // Skip parent items if they have variants but no variant is specified
            if ((item.hasVariants || item.variants.isNotEmpty) && variantId == null) {
              continue;
            }

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

      // If NOT paid (just saving), we only want KITCHEN tickets.
      final String title = isPaid ? "to'lov cheki" : "kitchen";
      final printKey = "${normalized['id']}_$title";
      processedPrintIds[printKey] = DateTime.now();

      await printOrder(normalized, 
          isKitchenOnly: !isPaid, 
          receiptTitle: isPaid ? "TO'LOV CHEKI" : null);

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
        orderToPrint['cancelled_items'] = cancelledItems;
        
        allOrders[index] = orderToPrint;

        final orderId = editingOrderId.value?.toString();
        if (orderId != null) {
          final String title = isPaid ? "to'lov cheki" : "kitchen";
          processedPrintIds["${orderId}_$title"] = DateTime.now();
        }

        // If NOT paid (just saving), we only want KITCHEN tickets.
        await printOrder(orderToPrint, 
            isKitchenOnly: !isPaid, 
            receiptTitle: isPaid ? "TO'LOV CHEKI" : null);

        allOrders.refresh();
        clearCurrentOrder();
        saveAllOrders();
        return true;
      }
      return false;
    } catch (e) { 
      return false; 
    }
  }

  void setTable(String table) {
    if (table.isNotEmpty) {
      bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      if (!isWithinGeofence.value && isWaiter && !isDesktop) {
        Get.snackbar("Hudud cheklovi", "Stol tanlash uchun kafe hududida bo'lishingiz kerak.", backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
    }
    
    editingOrderId.value = null;
    isOrderModified.value = false;
    currentOrder.clear();
    
    if (selectedTable.value.isNotEmpty) socket.emitTableUnlock(selectedTable.value);
    selectedTable.value = table;
    if (table.isNotEmpty) socket.emitTableLock(table, currentUser.value?['name'] ?? "User");
  }
  void setMode(String mode) => currentMode.value = mode;
  void toggleEditMode() => isEditMode.value = !isEditMode.value;
  void setDeviceRole(String? role) { deviceRole.value = role; storage.write('device_role', role); }
  void setWaiterCafeId(String? cafeId) { waiterCafeId.value = cafeId; storage.write('waiter_cafe_id', cafeId); }

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    storage.write('is_dark_mode', isDarkMode.value);
    Get.changeTheme(isDarkMode.value ? AppTheme.darkTheme : AppTheme.lightTheme);
  }

  void toggleFullScreen() async {
    isFullScreen.value = !isFullScreen.value;
    storage.write('is_full_screen', isFullScreen.value);
    _applyFullScreen(isFullScreen.value);
  }

  void _applyFullScreen(bool value) async {
    if (value) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> requestBill() async {
    // If it's a new order, we must save it first to get an ID
    if (editingOrderId.value == null) {
      if (currentOrder.isEmpty) {
        Get.snackbar("Xato", "Savat bo'sh", backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      
      // Save order first (as PENDING/PREPARING)
      // Note: submitOrder calls clearCurrentOrder() at the end
      bool success = await submitOrder(isPaid: false);
      if (!success) return;
      
      // After submission, we are back at the main screen and order is saved.
      // For immediate "Hisob" tracking, we'd need to re-find the order,
      // but usually, saving it is enough for a "new" order.
      // Let's just return here as submitOrder already printed a kitchen ticket and cleared the screen.
      return;
    }

    try {
      final orderId = editingOrderId.value!;
      
      // Update status on backend to BILL_PRINTED
      await updateOrderStatus(orderId, "BILL_PRINTED");

      // Print the bill
      final tempOrder = {
        "id": orderId,
        "table": selectedTable.value.isNotEmpty ? selectedTable.value : "-",
        "mode": currentMode.value,
        "total": total,
        "details": currentOrder.map((e) => {
          "id": (e['item'] as FoodItem).id,
          "name": (e['item'] as FoodItem).name,
          "qty": e['quantity'],
          "price": (e['item'] as FoodItem).price,
        }).toList(),
      };
      
      await printOrder(tempOrder, receiptTitle: "HISOB CHEKI");

      Get.snackbar(
        "order_locked_title".tr,
        "order_locked_msg".tr,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(Icons.lock_outline, color: Colors.white),
        snackPosition: SnackPosition.BOTTOM,
      );

      clearCurrentOrder();
      Get.offAll(() => MainNavigationScreen());
    } catch (e) {
      Get.snackbar("Xato", "Hisob so'rashda xatolik yuz berdi: $e", 
          backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void toggleAutoStart() async {
    isAutoStart.value = !isAutoStart.value;
    storage.write('is_auto_start', isAutoStart.value);
    
    if (Platform.isAndroid) {
      if (isAutoStart.value) {
        await isAutoStartAvailable;
        await getAutoStartPermission();
      }
    }
  }
}
