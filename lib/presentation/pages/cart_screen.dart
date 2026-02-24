import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
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
        title: Column(
          children: [
            Text("review_bill".tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Obx(() => Text(
              pos.selectedTable.value.isNotEmpty ? "${pos.selectedTable.value}-stol" : "Savat",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.normal),
            )),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          Obx(() => pos.currentOrder.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                onPressed: () => _showClearConfirmation(pos),
              )
            : const SizedBox.shrink()
          ),
        ],
      ),
      body: Obx(() {
        if (pos.currentOrder.isEmpty) return _buildEmptyCart();
        
        final newItems = [];
        final sentItems = [];
        final cancelledItems = [];
        
        for (int i = 0; i < pos.currentOrder.length; i++) {
          final item = pos.currentOrder[i];
          final int qty = item['quantity'];
          final int sentQty = item['sentQty'] ?? 0;
          
          if (item['isNew'] == true) {
            newItems.add({'index': i, 'data': item});
          } else {
            if (qty > 0) {
              sentItems.add({'index': i, 'data': item});
            }
            if (qty < sentQty) {
              cancelledItems.add({'index': i, 'data': item, 'cancelledQty': sentQty - qty});
            }
          }
        }

        return Column(
          children: [
            _buildModeSelector(pos),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  if (newItems.isNotEmpty) ...[
                    _buildSectionHeader("YANGI QO'SHILGANLAR", Colors.blue),
                    const SizedBox(height: 10),
                    ...newItems.map((wrapped) => _buildCartItem(wrapped['data'], wrapped['index'], pos)),
                  ],
                  if (sentItems.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader("SAVATDAGI BUYURTMALAR", Colors.green),
                    const SizedBox(height: 10),
                    ...sentItems.map((wrapped) => _buildCartItem(wrapped['data'], wrapped['index'], pos)),
                  ],
                  if (cancelledItems.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSectionHeader("BEKOR QILINGANLAR (ATKAZ)", Colors.red),
                    const SizedBox(height: 10),
                    ...cancelledItems.map((wrapped) => _buildCancelledItem(wrapped['data'], wrapped['cancelledQty'])),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() => pos.currentOrder.isEmpty ? const SizedBox.shrink() : _buildOrderSummary(pos)),
    );
  }

  void _showClearConfirmation(POSController pos) {
    Get.dialog(
      AlertDialog(
        title: const Text("Savatni tozalash?"),
        content: const Text("Barcha yangi qo'shilgan mahsulotlar o'chiriladi."),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Yo'q")),
          TextButton(
            onPressed: () {
              pos.clearCurrentOrder();
              Get.back();
            },
            child: const Text("Ha, tozalash", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(POSController pos) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: pos.orderModes.map((mode) {
          final isSelected = pos.currentMode.value == mode;
          String label = mode == "Dine-in" ? 'dine_in'.tr : (mode == "Takeaway" ? 'takeaway'.tr : 'delivery'.tr);
          return Expanded(
            child: GestureDetector(
              onTap: () => pos.setMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
                ),
                child: Center(
                  child: Text(label, style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey.shade600,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  )),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade200),
          ),
          const SizedBox(height: 24),
          Text("Savat bo'sh", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
          const SizedBox(height: 8),
          Text("Mahsulot tanlash uchun asosiy ekranga o'ting", style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Mahsulot qo'shish"),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> cartItem, int index, POSController pos) {
    final FoodItem item = cartItem['item'];
    final int qty = cartItem['quantity'];
    final bool isNew = cartItem['isNew'] == true;

    return Dismissible(
      key: Key("cart_${item.id}_$index"),
      direction: isNew ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => pos.removeFromCart(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isNew ? Colors.blue.withOpacity(0.15) : Colors.transparent, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CommonImage(imageUrl: item.imageUrl, width: 54, height: 54, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary))),
                      if (cartItem['timestamp'] != null)
                        Text(
                          DateFormat('HH:mm').format(DateTime.parse(cartItem['timestamp'])),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text("${item.price.toStringAsFixed(0)} ${pos.currency.value}", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildCounterButton(Icons.remove, () => pos.updateQuantity(index, -1)),
                  Container(
                    constraints: const BoxConstraints(minWidth: 36),
                    alignment: Alignment.center,
                    child: Text(qty.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  _buildCounterButton(Icons.add, () => pos.updateQuantity(index, 1), isAdd: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledItem(Map<String, dynamic> cartItem, int cancelledQty) {
    final FoodItem item = cartItem['item'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
              child: CommonImage(imageUrl: item.imageUrl, width: 44, height: 44, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                const SizedBox(height: 2),
                Text("-${(item.price * cancelledQty).toStringAsFixed(0)} ($cancelledQty ta)", style: TextStyle(color: Colors.red.shade300, fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text("Atkaz", style: TextStyle(color: Colors.red.shade400, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap, {bool isAdd = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isAdd ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: isAdd ? AppColors.primary : Colors.grey.shade400),
      ),
    );
  }

  Widget _buildOrderSummary(POSController pos) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -8))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Jami summa", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text("${pos.total.toStringAsFixed(0)} ${pos.currency.value}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  ],
                ),
                if (pos.isOrderModified.value)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text("O'zgartirildi", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildActionButton(
                    label: pos.isOrderModified.value ? "Saqlash & Send" : "Oshxonaga",
                    icon: Icons.soup_kitchen_rounded,
                    color: Colors.blue.shade600,
                    onTap: () async {
                      if (!pos.isOrderModified.value) {
                        Get.snackbar("Eslatma", "O'zgarishlar yo'q", backgroundColor: Colors.orange, colorText: Colors.white);
                        return;
                      }
                      bool success = await pos.submitOrder(isPaid: false);
                      if (success) {
                        Get.snackbar("Saqlandi", "Buyurtma oshxonaga yuborildi", backgroundColor: Colors.green, colorText: Colors.white);
                        Get.offAll(() => const MainNavigationScreen());
                      }
                    },
                    sublabel: pos.hasNewItems ? "Yangi mahsulot bor" : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: _buildActionButton(
                    label: "Hisob",
                    icon: Icons.receipt_long_rounded,
                    color: Colors.blueGrey.shade700,
                    onTap: () {
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
                    },
                  ),
                ),
                if (pos.isAdmin || pos.isCashier) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: _buildActionButton(
                      label: "To'lov",
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primary,
                      onTap: () async {
                        bool success = await pos.submitOrder(isPaid: true);
                        if (success) Get.offAll(() => const MainNavigationScreen());
                      },
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

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? sublabel,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
          if (sublabel != null)
            Text(sublabel, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.normal, color: Colors.white70)),
        ],
      ),
    );
  }
}
