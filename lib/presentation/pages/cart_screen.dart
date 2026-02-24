import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
import 'orders_screen.dart';
import 'main_navigation_screen.dart';
import '../widgets/common_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("review_bill".tr),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFF9500),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9500).withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ),
      body: Obx(() {
        if (pos.currentOrder.isEmpty) return _buildEmptyCart();
        
        // Group items
        final newItems = [];
        final sentItems = [];
        final cancelledItems = [];
        
        for (int i = 0; i < pos.currentOrder.length; i++) {
          final item = pos.currentOrder[i];
          final bool isNew = item['isNew'] == true;
          final int quantity = item['quantity'] ?? 0;
          
          if (isNew) {
            newItems.add({'index': i, 'data': item});
          } else if (quantity > 0) {
            sentItems.add({'index': i, 'data': item});
          } else {
            cancelledItems.add({'index': i, 'data': item});
          }
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          children: [
            _buildModeSelector(pos),
            
            // New Items Section
            if (newItems.isNotEmpty) ...[
              _buildSectionHeader("Yangi mahsulotlar", Colors.blue),
              ...newItems.map((wrapped) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCartItem(wrapped['data'], wrapped['index'], pos),
              )),
              const SizedBox(height: 16),
            ],
            
            // Sent Items Section (Collapsible)
            if (sentItems.isNotEmpty) ...[
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: _buildSectionHeader("Eski buyurtmalar (Oshxonaga yuborilgan)", Colors.green),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: true,
                  children: sentItems.map((wrapped) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildCartItem(wrapped['data'], wrapped['index'], pos),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Cancelled Items Section
            if (cancelledItems.isNotEmpty) ...[
              _buildSectionHeader("Bekor qilingan mahsulotlar", Colors.red),
              ...cancelledItems.map((wrapped) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCartItem(wrapped['data'], wrapped['index'], pos),
              )),
              const SizedBox(height: 16),
            ],
            
            _buildOrderSummary(pos),
          ],
        );
      }),
    );
  }

  Widget _buildModeSelector(POSController pos) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: pos.orderModes.map((mode) {
          final isSelected = pos.currentMode.value == mode;
          String translatedLabel = mode.toLowerCase() == "dine-in" ? 'dine_in'.tr : (mode.toLowerCase() == "takeaway" ? 'takeaway'.tr : 'delivery'.tr);
          return Expanded(
            child: GestureDetector(
              onTap: () => pos.setMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    translatedLabel,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("current_bill_empty".tr, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Get.back(), child: Text("back_to_terminal".tr)),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> cartItem, int index, POSController pos) {
    final FoodItem item = cartItem['item'];
    final int quantity = cartItem['quantity'];
    final bool isNew = cartItem['isNew'] == true;
    final int sentQty = cartItem['sentQty'] ?? 0;
    final bool isCancelled = !isNew && quantity == 0;
    final bool isPartialCancelled = !isNew && quantity < sentQty && quantity > 0;

    return Opacity(
      opacity: isCancelled ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNew 
            ? const Color(0xFFEFF6FF) 
            : (isCancelled ? Colors.grey.shade50 : AppColors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          border: isNew ? Border.all(color: Colors.blue.shade100) : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15), 
                  child: CommonImage(
                    imageUrl: item.imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                if (isCancelled)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
                      child: const Icon(Icons.close, color: Colors.white, size: 30),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.name, 
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.bold, 
                            color: AppColors.textPrimary,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          )
                        ),
                      ),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
                          child: const Text("Yangi", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isPartialCancelled)
                    Text("${sentQty - quantity} ta bekor qilindi", 
                      style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))
                  else if (isCancelled)
                    const Text("Bekor qilingan", 
                      style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))
                  else
                    Text("\$${item.price.toStringAsFixed(2)}", 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  if (cartItem['createdAt'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "Vaqti: ${DateTime.parse(cartItem['createdAt']).toLocal().toString().substring(11, 16)}",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              children: [
                _buildSmallQtyBtn(Icons.add, () => pos.updateQuantity(index, 1), isPrimary: true),
                GestureDetector(
                  onTap: () => pos.showQuantityDialog(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8), 
                    child: Text(quantity.toString(), 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16,
                        color: isCancelled ? Colors.red : AppColors.textPrimary,
                      )
                    )
                  ),
                ),
                _buildSmallQtyBtn(Icons.remove, () => pos.updateQuantity(index, -1)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallQtyBtn(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12), // Increased from 4
        decoration: BoxDecoration(color: isPrimary ? AppColors.primary : Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), // Increased radius
        child: Icon(icon, size: 24, color: isPrimary ? Colors.white : AppColors.textPrimary), // Increased from 16
      ),
    );
  }

  Widget _buildOrderSummary(POSController pos) {
    String modeLabel = pos.currentMode.value.toLowerCase() == "dine-in" ? 'dine_in'.tr : (pos.currentMode.value.toLowerCase() == "takeaway" ? 'takeaway'.tr : 'delivery'.tr);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildSummaryRow("subtotal".tr, "\$${pos.subtotal.toStringAsFixed(2)}"),
            _buildSummaryRow(
              pos.currentMode.value == "Dine-in"
                ? "$modeLabel ${'fee'.tr} (${pos.serviceFeeDineIn.value.toStringAsFixed(0)}%)"
                : "$modeLabel ${'fee'.tr}",
              "\$${pos.serviceFee.toStringAsFixed(2)}"
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            _buildSummaryRow("total".tr, "\$${pos.total.toStringAsFixed(2)}", isTotal: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                    if (!pos.hasNewItems) {
                      Get.snackbar("Eslatma", "Oshxonaga yuborish uchun yangi mahsulot qo'shilmadi", 
                        backgroundColor: Colors.orange, colorText: Colors.white);
                      return;
                    }
                    bool success = await pos.submitOrder(isPaid: false);
                    if (success) {
                      Get.offAll(() => const MainNavigationScreen());
                    }
                  },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 75), 
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.print_rounded, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          "kitchen_print".tr, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final tempOrder = {
                        "id": pos.editingOrderId.value ?? "NEW",
                        "table": pos.selectedTable.value.isNotEmpty ? pos.selectedTable.value : "-",
                        "mode": pos.currentMode.value,
                        "total": pos.total,
                        "details": pos.currentOrder.map((e) => {
                          "id": (e['item'] as FoodItem).id,
                          "name": (e['item'] as FoodItem).name,
                          "qty": e['quantity'],
                          "price": (e['item'] as FoodItem).price,
                        }).toList(),
                      };
                      pos.printOrder(tempOrder, receiptTitle: "HISOB CHEKI");
                      if (pos.editingOrderId.value != null) {
                        pos.updateOrderStatus(pos.editingOrderId.value!, "Bill Printed");
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 75), 
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      side: const BorderSide(color: Colors.blue, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 20, color: Colors.blue),
                        const SizedBox(height: 4),
                        Text(
                          "print_receipt".tr, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                if (pos.isAdmin) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        bool success = await pos.submitOrder(isPaid: true);
                        if (success) {
                          Get.offAll(() => const MainNavigationScreen());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 75), 
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            "pay_finish".tr, 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 20 : 15, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: isTotal ? 20 : 15, fontWeight: FontWeight.bold, color: isTotal ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }
}
