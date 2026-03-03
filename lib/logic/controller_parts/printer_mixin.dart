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

    // Terminal rejimida (kassa sifatida ulangan) → DOIM lokal chop etadi
    final bool isTerminalMode = currentTerminal.value != null;

    // Faqat terminal YO'Q va rol WAITER bo'lsa → kassaga socket orqali yuboradi
    if (!isTerminalMode && (deviceRole.value == "WAITER" || isWaiter)) {
      socket.emitPrintRequest({
        'order': order,
        'isKitchenOnly': isKitchenOnly,
        'receiptTitle': receiptTitle,
        'sender': currentUser.value?['name'] ?? "Waiter",
      });
      Get.snackbar("Chop etish yuborildi", "Kassaga yuborildi", 
        backgroundColor: Colors.blue.withOpacity(0.8), 
        colorText: Colors.white,
        duration: const Duration(seconds: 1),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(10),
      );
      return;
    }

    // Terminal rejimi yoki Cashier/Admin → bevosita chop etadi
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
            
            final areaItems = details.where((d) {
              final itemId = d['id']?.toString().trim();
              if (itemId == null) return false;
              final product = products.firstWhereOrNull((p) => p.id.toString().trim() == itemId);
              if (product == null || product.preparationAreaId == null) return false;
              final String prodAreaId = product.preparationAreaId.toString().trim();
              return printer.preparationAreaIds.any((id) => id.trim() == prodAreaId);
            }).toList();

            if (areaItems.isNotEmpty || previouslyPrinted.isNotEmpty) {
              // Group items by preparationAreaId
              final Map<String, List<dynamic>> itemsByArea = {};
              for (var item in areaItems) {
                final product = products.firstWhereOrNull((p) => p.id.toString().trim() == item['id'].toString().trim());
                final areaId = product?.preparationAreaId?.toString() ?? "unknown";
                itemsByArea.putIfAbsent(areaId, () => []).add(item);
              }

              // Identify all unique areas that had items previously or have items now for this printer
              final Set<String> allActiveAreaIds = {
                ...itemsByArea.keys,
                ...previouslyPrinted.keys.map((pId) {
                  final product = products.firstWhereOrNull((p) => p.id.toString().trim() == pId.trim());
                  return product?.preparationAreaId?.toString() ?? "unknown";
                }).where((aId) => printer.preparationAreaIds.any((pAId) => pAId.trim() == aId.trim()))
              };

              bool jobPrintedOverall = false;

              for (final areaId in allActiveAreaIds) {
                final currentAreaItems = itemsByArea[areaId] ?? [];
                
                // Get area name from products
                String areaName = "Oshxona";
                final areaProduct = products.firstWhereOrNull((p) => p.preparationAreaId?.toString() == areaId);
                if (areaProduct != null) areaName = areaProduct.preparationArea;

                List<dynamic> addedItems = [];
                List<dynamic> cancelledItems = [];

                for (var item in currentAreaItems) {
                  final String pId = item['id'].toString();
                  final int currentQty = int.tryParse(item['qty'].toString()) ?? 0;
                  final int prevQty = previouslyPrinted[pId] ?? 0;
                  if (currentQty > prevQty) addedItems.add({...item, 'qty': currentQty - prevQty});
                }

                previouslyPrinted.forEach((pId, prevQty) {
                  final product = products.firstWhereOrNull((p) => p.id.toString().trim() == pId.trim());
                  if (product != null && product.preparationAreaId?.toString() == areaId) {
                    final currentItem = currentAreaItems.firstWhereOrNull((i) => i['id'].toString() == pId);
                    final int currentQty = currentItem != null ? (int.tryParse(currentItem['qty'].toString()) ?? 0) : 0;
                    if (currentQty < prevQty) {
                      cancelledItems.add({'id': pId, 'name': product.name, 'qty': prevQty - currentQty});
                    }
                  }
                });

                if (addedItems.isNotEmpty) {
                  success = await printerService.printKitchenTicket(printer, order, addedItems, title: areaName);
                  if (success) { successPrinters.add("${printer.name} ($areaName)"); jobPrintedOverall = true; } 
                  else failedPrinters.add("${printer.name} ($areaName)");
                }
                
                if (cancelledItems.isNotEmpty) {
                  success = await printerService.printCancellationTicket(printer, order, cancelledItems, title: "$areaName Bekor");
                  if (success) { successPrinters.add("${printer.name} ($areaName Bekor)"); jobPrintedOverall = true; } 
                  else failedPrinters.add("${printer.name} ($areaName Bekor xatosi)");
                }
              }

              if (jobPrintedOverall) {
                final currentPrintedMap = Map<String, int>.from(printedKitchenQuantities[orderIdStr] ?? {});
                for (var item in areaItems) {
                  currentPrintedMap[item['id'].toString()] = int.tryParse(item['qty'].toString()) ?? 0;
                }
                printedKitchenQuantities[orderIdStr] = currentPrintedMap;
                storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
              }

              if (jobPrintedOverall == false && !shouldPrintCurrentReceipt) {
                filteredPrinters.add(printer.name);
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
