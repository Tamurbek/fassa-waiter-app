import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/printer_model.dart';
import 'pos_controller_state.dart';
import '../../data/models/food_item.dart';

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

    if (deviceRole.value == "WAITER" || isWaiter) {
      socket.emitPrintRequest({
        'order': order,
        'isKitchenOnly': isKitchenOnly,
        'receiptTitle': receiptTitle,
        'sender': currentUser.value?['name'] ?? "Waiter",
      });
      Get.snackbar("Chop etish yuborildi", "Kassaga yuborildi", backgroundColor: Colors.blue, colorText: Colors.white);
      return;
    }

    await printLocally(order, isKitchenOnly: isKitchenOnly, receiptTitle: receiptTitle);
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
          final String orderAreaName = orderTableId.contains("-") ? orderTableId.split("-")[0] : "";
          if (!printer.tableAreaNames.contains(orderAreaName)) shouldPrintCurrentReceipt = false;
        }

        if (shouldPrintCurrentReceipt && !isKitchenOnly) {
          if ((receiptTitle == "HISOB CHEKI" && !enableBillPrint.value) || 
              (receiptTitle != "HISOB CHEKI" && !enablePaymentPrint.value)) {
            // Disabled
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
            
            List<dynamic> addedItems = [];
            List<dynamic> cancelledItems = [];

            final areaItems = details.where((d) {
              final itemId = d['id']?.toString().trim();
              if (itemId == null) return false;
              final product = products.firstWhereOrNull((p) => p.id.toString().trim() == itemId);
              if (product == null || product.preparationAreaId == null) return false;
              final String prodAreaId = product.preparationAreaId.toString().trim();
              return printer.preparationAreaIds.any((id) => id.trim() == prodAreaId);
            }).toList();

            if (areaItems.isNotEmpty || previouslyPrinted.isNotEmpty) {
              for (var item in areaItems) {
                final String pId = item['id'].toString();
                final int currentQty = int.tryParse(item['qty'].toString()) ?? 0;
                final int prevQty = previouslyPrinted[pId] ?? 0;
                if (currentQty > prevQty) addedItems.add({...item, 'qty': currentQty - prevQty});
              }

              if (previouslyPrinted.isNotEmpty) {
                previouslyPrinted.forEach((pId, prevQty) {
                  final product = products.firstWhereOrNull((p) => p.id.toString().trim() == pId.trim());
                  if (product != null && product.preparationAreaId != null) {
                    final String prodAreaId = product.preparationAreaId.toString().trim();
                    if (printer.preparationAreaIds.any((id) => id.trim() == prodAreaId)) {
                      final currentItem = areaItems.firstWhereOrNull((i) => i['id'].toString() == pId);
                      final int currentQty = currentItem != null ? (int.tryParse(currentItem['qty'].toString()) ?? 0) : 0;
                      if (currentQty < prevQty) {
                        cancelledItems.add({'id': pId, 'name': product.name, 'qty': prevQty - currentQty});
                      }
                    }
                  }
                });
              }

              bool jobPrinted = false;
              if (addedItems.isNotEmpty) {
                success = await printerService.printKitchenTicket(printer, order, addedItems);
                if (success) { successPrinters.add("${printer.name} (Yangilar)"); jobPrinted = true; } 
                else failedPrinters.add(printer.name);
              }
              if (cancelledItems.isNotEmpty) {
                success = await printerService.printCancellationTicket(printer, order, cancelledItems);
                if (success) { successPrinters.add("${printer.name} (Bekor)"); jobPrinted = true; } 
                else failedPrinters.add("${printer.name} (Bekor xatosi)");
              }

              if (jobPrinted) {
                final currentPrintedMap = Map<String, int>.from(printedKitchenQuantities[orderIdStr] ?? {});
                for (var item in areaItems) {
                  currentPrintedMap[item['id'].toString()] = int.tryParse(item['qty'].toString()) ?? 0;
                }
                printedKitchenQuantities[orderIdStr] = currentPrintedMap;
                storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
              }

              if (addedItems.isEmpty && cancelledItems.isEmpty) {
                if (!shouldPrintCurrentReceipt) filteredPrinters.add(printer.name);
              }
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
      Get.snackbar("Printer", "Muvaffaqiyatli chop etildi", backgroundColor: Colors.green, colorText: Colors.white);
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
