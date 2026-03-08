import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/printer_model.dart';
import 'pos_controller_state.dart';

mixin PrinterMixin on POSControllerState {
  Future<void> printOrder(Map<String, dynamic> order, {bool isKitchenOnly = false, String? receiptTitle}) async {
    if (!isWithinGeofence.value && currentUser.value?['role'] == "WAITER") {
      Get.snackbar("Diqqat", "Siz ish joyidan tashqaridasiz.", backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (!order.containsKey('waiter_name')) {
      final name = currentUser.value?['name'];
      if (name != null) order['waiter_name'] = name;
    }

    // Force all printing to go through the central POS terminal via Socket
    socket.emitPrintRequest({
      'order': order,
      'isKitchenOnly': isKitchenOnly,
      'receiptTitle': receiptTitle,
      'sender': currentUser.value?['name'] ?? "Waiter",
    });
    
    Get.snackbar(
      "Chop etish yuborildi", 
      "Kassaga yuborildi", 
      backgroundColor: Colors.blue.withOpacity(0.8), 
      colorText: Colors.white,
      duration: const Duration(seconds: 1),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(10),
    );
  }

  Future<void> printLocally(Map<String, dynamic> order, {bool isKitchenOnly = false, String? receiptTitle}) async {
    isPrinting.value = true;
    List<String> successPrinters = [];
    List<String> failedPrinters = [];
    List<String> filteredPrinters = [];
    
    final details = order['details'] as List? ?? [];
    final activePrinters = printers.where((p) => p.isActive).toList();
    
    if (activePrinters.isEmpty) {
      Get.snackbar("Printer Warning", "No active printers configured", 
        backgroundColor: Colors.orange, colorText: Colors.white);
      isPrinting.value = false;
      return;
    }

    for (var printer in activePrinters) {
      try {
        bool success = false;
        bool shouldPrintCurrentReceipt = false;
        
        if (receiptTitle == "HISOB CHEKI" && printer.printReceipts) {
          shouldPrintCurrentReceipt = true;
        } else if (receiptTitle == null && !isKitchenOnly && printer.printPayments) {
          shouldPrintCurrentReceipt = true;
        } else if (receiptTitle != null && receiptTitle != "HISOB CHEKI" && printer.printPayments) {
          shouldPrintCurrentReceipt = true;
        }

        if (shouldPrintCurrentReceipt && printer.tableAreaNames.isNotEmpty) {
          final String orderTableId = (order['table'] ?? "").toString();
          final String? orderAreaName = order['table_area']?.toString() ?? 
                                       (orderTableId.contains("-") ? orderTableId.split("-")[0] : null);
          
          if (orderAreaName != null && orderAreaName.isNotEmpty) {
            if (!printer.tableAreaNames.contains(orderAreaName)) shouldPrintCurrentReceipt = false;
          }
        }

        if (shouldPrintCurrentReceipt && (!isKitchenOnly || receiptTitle != null)) {
          if ((receiptTitle == "HISOB CHEKI" && !enableBillPrint.value) || 
              (receiptTitle != "HISOB CHEKI" && receiptTitle != null && !enablePaymentPrint.value)) {
            // Disabled in settings
          } else {
            final orderForPrinting = Map<String, dynamic>.from(order);
            orderForPrinting['service_fee_dine_in'] = serviceFeeDineIn.value;
            orderForPrinting['service_fee_takeaway'] = serviceFeeTakeaway.value;
            orderForPrinting['service_fee_delivery'] = serviceFeeDelivery.value;
            
            success = await printerService.printReceipt(printer, orderForPrinting, title: receiptTitle);
            if (success) successPrinters.add(printer.name);
            else failedPrinters.add(printer.name);
          }
        }

        if (printer.preparationAreaIds.isNotEmpty && (isKitchenOnly || receiptTitle == null)) {
          if (enableKitchenPrint.value) {
            final orderIdStr = order['id']?.toString() ?? "0";
            final previouslyPrintedRaw = printedKitchenQuantities[orderIdStr];
            final Map<String, int> previouslyPrinted = previouslyPrintedRaw != null 
                ? Map<String, int>.from(previouslyPrintedRaw) : {};
            
            bool jobPrintedOnThisPrinter = false;
            final Set<String> printerAreaIds = printer.preparationAreaIds.map((id) => id.trim()).toSet();

            // Group items of THIS printer by their specific areaId
            final Map<String, List<dynamic>> addedByArea = {};
            final Map<String, List<dynamic>> cancelledByArea = {};

            // 1. Calculate ADDED items per area
            for (var item in details) {
              final String productId = item['id']?.toString().trim() ?? "";
              final String? variantId = item['variant_id']?.toString().trim();
              final String itemKey = variantId != null ? "${productId}_$variantId" : productId;
              
              final product = products.firstWhereOrNull((p) => p.id.toString().trim() == productId);
              if (product == null || product.preparationAreaId == null) continue;
              
              final String prodAreaId = product.preparationAreaId.toString().trim();
              if (!printerAreaIds.contains(prodAreaId)) continue; 

              final int currentQty = int.tryParse(item['qty'].toString()) ?? 0;
              final int prevQty = previouslyPrinted[itemKey] ?? 0;

              if (currentQty > prevQty) {
                addedByArea.putIfAbsent(prodAreaId, () => []).add({...item, 'qty': currentQty - prevQty});
              }
            }

            // 2. Calculate CANCELLED items per area
            previouslyPrinted.forEach((itemKey, prevQty) {
              final String productId = itemKey.contains("_") ? itemKey.split("_")[0] : itemKey;
              final product = products.firstWhereOrNull((p) => p.id.toString().trim() == productId);
              if (product == null || product.preparationAreaId == null) return;
              
              final String prodAreaId = product.preparationAreaId.toString().trim();
              if (!printerAreaIds.contains(prodAreaId)) return;

              final currentItem = details.firstWhereOrNull((i) {
                final iProdId = i['id']?.toString().trim() ?? "";
                final iVarId = i['variant_id']?.toString().trim();
                return (iVarId != null ? "${iProdId}_$iVarId" : iProdId) == itemKey;
              });

              final int currentQty = currentItem != null ? (int.tryParse(currentItem['qty'].toString()) ?? 0) : 0;
              if (currentQty < prevQty) {
                cancelledByArea.putIfAbsent(prodAreaId, () => []).add({
                  'id': productId, 
                  'name': currentItem != null ? currentItem['name'] : product.name, 
                  'qty': prevQty - currentQty
                });
              }
            });

            // 3. Print tickets (One per area)
            final Set<String> allActiveAreasOnThisPrinter = {...addedByArea.keys, ...cancelledByArea.keys};
            for (final areaId in allActiveAreasOnThisPrinter) {
              String areaName = "Oshxona";
              final areaProduct = products.firstWhereOrNull((p) => p.preparationAreaId?.toString() == areaId);
              if (areaProduct != null) areaName = areaProduct.preparationArea;

              final added = addedByArea[areaId] ?? [];
              if (added.isNotEmpty) {
                success = await printerService.printKitchenTicket(printer, order, added, title: areaName);
                if (success) { successPrinters.add("${printer.name} ($areaName)"); jobPrintedOnThisPrinter = true; } 
                else failedPrinters.add("${printer.name} ($areaName)");
              }

              if (cancelledByArea[areaId]?.isNotEmpty == true) {
                success = await printerService.printCancellationTicket(printer, order, cancelledByArea[areaId]!, title: "$areaName BEKOR");
                if (success) { successPrinters.add("${printer.name} ($areaName Bekor)"); jobPrintedOnThisPrinter = true; } 
                else failedPrinters.add("${printer.name} ($areaName Bekor xatosi)");
              }
            }

            // 4. Update sync state
            if (jobPrintedOnThisPrinter) {
              final currentPrintedMap = Map<String, int>.from(printedKitchenQuantities[orderIdStr] ?? {});
              for (var item in details) {
                 final String productId = item['id']?.toString().trim() ?? "";
                 final String? variantId = item['variant_id']?.toString().trim();
                 final String itemKey = variantId != null ? "${productId}_$variantId" : productId;
                 final product = products.firstWhereOrNull((p) => p.id.toString().trim() == productId);
                 if (product != null && product.preparationAreaId != null && printerAreaIds.contains(product.preparationAreaId.toString().trim())) {
                      currentPrintedMap[itemKey] = int.tryParse(item['qty'].toString()) ?? 0;
                 }
              }
              printedKitchenQuantities[orderIdStr] = currentPrintedMap;
              storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
            }

            if (jobPrintedOnThisPrinter == false && !shouldPrintCurrentReceipt) {
              filteredPrinters.add(printer.name);
            }
          }
        }
      } catch (e) {
        failedPrinters.add(printer.name);
      }
    }
    
    isPrinting.value = false;
    if (failedPrinters.isNotEmpty) {
      Get.snackbar("Printer Error", "Failed: ${failedPrinters.join(', ')}", backgroundColor: Colors.red, colorText: Colors.white);
    } else if (successPrinters.isNotEmpty) {
      Get.snackbar("Printer", "Muvaffaqiyatli chop etildi", 
        backgroundColor: Colors.green.withOpacity(0.8), 
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(10),
      );
    }
  }

  Future<void> testPrinter(PrinterModel printer) async {
    await printerService.printTestPage(printer);
  }

  Future<void> addPrinter(PrinterModel printer) async {
    try {
      final json = printer.toJson();
      json['cafe_id'] = cafeId;
      final newPrinter = await api.createPrinter(json);
      printers.add(PrinterModel.fromJson(newPrinter));
      savePrinters();
    } catch (e) { print("Error adding printer: $e"); }
  }

  Future<void> updatePrinter(PrinterModel printer) async {
    try {
      final json = printer.toJson();
      json.remove('id');
      final updatedPrinter = await api.updatePrinter(printer.id, json);
      int index = printers.indexWhere((p) => p.id == printer.id);
      if (index != -1) {
        printers[index] = PrinterModel.fromJson(updatedPrinter);
        savePrinters();
      }
    } catch (e) { print("Error updating printer: $e"); }
  }

  Future<void> deletePrinter(String id) async {
    try {
      await api.deletePrinter(id);
      printers.removeWhere((p) => p.id == id);
      savePrinters();
    } catch (e) { print("Error deleting printer: $e"); }
  }
}
