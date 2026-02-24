import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/food_item.dart';
import 'home_screen.dart';
import 'table_selection_screen.dart';
import 'cart_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final List<FoodItem> catalog = pos.products;
    final bool isMobile = Responsive.isMobile(context);
    final RxString selectedFilter = "All".obs;
    final Rxn<Map<String, dynamic>> selectedOrder = Rxn<Map<String, dynamic>>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text("order_management".tr),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => _showLanguageSwitcher(context),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: "active".tr),
              Tab(text: "history".tr),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => pos.allOrders.refresh(),
            ),
            IconButton(
              icon: const Icon(Icons.lock_rounded, color: Colors.orange),
              onPressed: () => pos.lockTerminal(),
              tooltip: "Terminalni qulflash",
            ),
            if (!isMobile)
              Obx(() => IconButton(
                icon: Icon(pos.isOrdersTableView.value ? Icons.grid_view_rounded : Icons.view_list_rounded),
                onPressed: () => pos.toggleOrdersViewMode(),
                tooltip: pos.isOrdersTableView.value ? "switch_to_cards".tr : "switch_to_table".tr,
              )),
            if (!isMobile) const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Obx(() => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildFilterChip("All", "all".tr, selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip("Dine-in", 'dine_in'.tr, selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip("Takeaway", 'takeaway'.tr, selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip("Delivery", 'delivery'.tr, selectedFilter),
                ],
              )),
            ),
            // Global Action Bar
            Obx(() => _buildGlobalToolbar(selectedOrder, pos, catalog, context)),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  Obx(() {
                    var filtered = pos.allOrders.where((o) => o['status'] != "Completed").toList();
                    if (selectedFilter.value != "All") {
                      filtered = filtered.where((o) => o['mode'] == selectedFilter.value).toList();
                    } else {
                      filtered = _sortOrders(filtered);
                    }
                    return filtered.isEmpty
                        ? _buildEmptyState("no_active_orders".tr, "start_new_sale".tr)
                        : (pos.isOrdersTableView.value && !isMobile 
                            ? _buildOrdersTable(filtered, pos, catalog, context, selectedOrder)
                            : _buildOrdersGrid(filtered, pos, catalog, context, selectedOrder));
                  }),
                  Obx(() {
                    var filtered = pos.allOrders.where((o) => o['status'] == "Completed").toList();
                    if (selectedFilter.value != "All") {
                      filtered = filtered.where((o) => o['mode'] == selectedFilter.value).toList();
                    } else {
                      filtered = _sortOrders(filtered);
                    }
                    return filtered.isEmpty
                        ? _buildEmptyState("no_completed_orders".tr, "history_empty".tr)
                        : (pos.isOrdersTableView.value && !isMobile 
                            ? _buildOrdersTable(filtered, pos, catalog, context, selectedOrder)
                            : _buildOrdersGrid(filtered, pos, catalog, context, selectedOrder));
                  }),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Obx(() {
          if (pos.isWaiter && !pos.allowWaiterMobileOrders.value) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            heroTag: 'orders_fab',
            onPressed: () => _showOrderTypeDialog(context, pos),
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.add, color: Colors.white),
          );
        }),
      ),
    );
  }

  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    final Map<String, int> modePriority = {
      "Dine-in": 0,
      "Takeaway": 1,
      "Delivery": 2,
    };
    
    final sorted = List<Map<String, dynamic>>.from(orders);
    sorted.sort((a, b) {
      int pA = modePriority[a['mode']] ?? 99;
      int pB = modePriority[b['mode']] ?? 99;
      return pA.compareTo(pB);
    });
    return sorted;
  }

  Widget _buildOrdersTable(List<Map<String, dynamic>> orders, POSController pos, List<FoodItem> catalog, BuildContext context, Rxn<Map<String, dynamic>> selectedOrder) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Obx(() => DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.background),
          dividerThickness: 1,
          showCheckboxColumn: false,
          columns: [
            DataColumn(label: Text('# ID', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('table'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Type', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('total'.tr, style: const TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: orders.map((order) {
            final isSelected = selectedOrder.value?['id'] == order['id'];
            return DataRow(
              selected: isSelected,
              onSelectChanged: (selected) {
                if (selected ?? false) {
                  selectedOrder.value = order;
                }
              },
              cells: [
                DataCell(Text(order['id'].toString().length > 8 ? order['id'].toString().substring(0, 8) : order['id'].toString())),
                DataCell(Text(order['table'] ?? "—")),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(order['mode'] ?? "Dine-in", style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                )),
                DataCell(Text("${order['total'].toStringAsFixed(0)} so'm", style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(_buildStatusBadge(order['status'] ?? "Pending")),
              ],
            );
          }).toList(),
        )),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == "Completed") color = Colors.green;
    if (status == "Pending") color = Colors.orange;
    if (status == "Bill Printed") color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.tr, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilterChip(String value, String label, RxString selectedFilter) {
    final bool isSelected = selectedFilter.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) selectedFilter.value = value;
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade200),
      ),
    );
  }

  Widget _buildOrdersGrid(List<Map<String, dynamic>> orders, POSController pos, List<FoodItem> catalog, BuildContext context, Rxn<Map<String, dynamic>> selectedOrder) {
    final int crossAxisCount = Responsive.isMobile(context) ? 1 : (Responsive.isTablet(context) ? 2 : 3);
    final isMobile = Responsive.isMobile(context);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 24 : 40, 
        10,
        isMobile ? 24 : 40, 
        100
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 450,
        mainAxisExtent: isMobile ? 150 : 160,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Obx(() {
          final isSelected = selectedOrder.value?['id'] == order['id'];
          return GestureDetector(
            onTap: () => selectedOrder.value = order,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: _buildSlidableOrderCard(order, pos, catalog, context, isSelected),
            ),
          );
        });
      },
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Sizning tilingiz / Ваш язык / Your Language", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildLangItem("O'zbekcha", 'uz', 'UZ'),
            _buildLangItem("English", 'en', 'US'),
            _buildLangItem("Русский", 'ru', 'RU'),
          ],
        ),
      ),
    );
  }

  Widget _buildLangItem(String label, String langCode, String countryCode) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final locale = Locale(langCode, countryCode);
        Get.updateLocale(locale);
        GetStorage().write('lang', '${langCode}_$countryCode');
        Get.back();
      },
      trailing: Get.locale?.languageCode == langCode ? const Icon(Icons.check, color: AppColors.primary) : null,
    );
  }

  Widget _buildSlidableOrderCard(Map<String, dynamic> order, POSController pos, List<FoodItem> catalog, BuildContext context, bool isSelected) {
    final bool isActive = order['status'] != "Completed";
    return _buildOrderCardContent(order, pos, catalog, isActive, context, isSelected);
  }

  Widget _buildOrderCardContent(Map<String, dynamic> order, POSController pos, List<FoodItem> catalog, bool isActive, BuildContext context, bool isSelected) {
    final status = order['status'];
    final mode = order['mode'] ?? "Dine-in";
    String modeLabel = mode.toString().toLowerCase() == "dine-in" ? 'dine_in'.tr : (mode.toString().toLowerCase() == "takeaway" ? 'takeaway'.tr : 'delivery'.tr);
    final bool isMobile = Responsive.isMobile(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Order #${order['id']}", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (isActive) _buildActionIcon(status, order, pos, catalog),
                      ],
                    ),
                    Text(
                      "${order['table']} • $modeLabel • ${order['items']} ${'items'.tr}", 
                      style: TextStyle(color: AppColors.textSecondary, fontSize: isMobile ? 12 : 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "${'total'.tr}: \$${order['total'].toStringAsFixed(2)}", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18, color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 18),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildEndAction(dynamic status, Map<String, dynamic> order, POSController pos, List<FoodItem> catalog) {
    if (status == "Bill Printed") {
       if (pos.isAdmin || pos.isCashier) {
         return SlidableAction(
           onPressed: (context) => _confirmUnlock(order['id'], pos),
           backgroundColor: Colors.orange,
           foregroundColor: Colors.white,
           icon: Icons.lock_open,
           label: 'unlock'.tr,
           borderRadius: BorderRadius.circular(20),
         );
       }
       return const SizedBox.shrink(); 
    } else {
       return SlidableAction(
        onPressed: (context) => _handleOrderEdit(order, pos, catalog),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: Icons.edit_outlined,
        label: 'edit'.tr,
        borderRadius: BorderRadius.circular(20),
      );
    }
  }

  Widget _buildActionIcon(dynamic status, Map<String, dynamic> order, POSController pos, List<FoodItem> catalog) {
    if (status == "Bill Printed") {
      return GestureDetector(
        onTap: () => _handleOrderEdit(order, pos, catalog),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
          child: Tooltip(
            message: "pay".tr,
            child: Icon(Icons.lock, size: 20, color: Colors.orange.withOpacity((pos.isAdmin || pos.isCashier) ? 1.0 : 0.5)),
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _handleOrderEdit(order, pos, catalog),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.add, size: 20, color: AppColors.primary),
        ),
      );
    }
  }

  void _confirmUnlock(int orderId, POSController pos) {
    Get.dialog(
      AlertDialog(
        title: Text("unlock_order".tr),
        content: Text("unlock_order_msg".tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
          TextButton(
            onPressed: () {
              pos.updateOrderStatus(orderId, "Pending");
              Get.back();
              Get.snackbar("Success", "Order #$orderId unlocked", backgroundColor: Colors.green, colorText: Colors.white);
            }, 
            child: Text("unlock".tr, style: const TextStyle(color: Colors.orange))
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int orderId, POSController pos) {
    Get.dialog(
      AlertDialog(
        title: Text("delete_confirm_title".tr),
        content: Text("delete_confirm_msg".tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
          TextButton(
            onPressed: () {
              pos.deleteOrder(orderId);
              Get.back();
              Get.snackbar("Deleted", "Order #$orderId has been removed", backgroundColor: Colors.red, colorText: Colors.white);
            }, 
            child: Text("delete".tr, style: const TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showOrderTypeDialog(BuildContext context, POSController pos) {
    if (pos.isWaiter) {
      pos.clearCurrentOrder(); 
      pos.setMode("Dine-in");
      Get.to(() => const TableSelectionScreen());
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        constraints: BoxConstraints(maxWidth: Responsive.isMobile(context) ? double.infinity : 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("select_order_type".tr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildModeOption(Icons.restaurant, "Dine-in", pos),
                const SizedBox(width: 16),
                _buildModeOption(Icons.shopping_bag, "Takeaway", pos),
                const SizedBox(width: 16),
                _buildModeOption(Icons.delivery_dining, "Delivery", pos),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(IconData icon, String label, POSController pos) {
    return Expanded(
      child: InkWell(
        onTap: () {
          pos.clearCurrentOrder(); 
          pos.setMode(label);
          Get.back(); 
          if (label == "Dine-in") {
            Get.to(() => const TableSelectionScreen());
          } else {
            Get.to(() => const HomeScreen());
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalToolbar(Rxn<Map<String, dynamic>> selectedOrder, POSController pos, List<FoodItem> catalog, BuildContext context) {
    final order = selectedOrder.value;
    final bool hasSelection = order != null;
    final bool isActive = hasSelection && order['status'] != "Completed";
    final String status = hasSelection ? order['status'] : "";

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildToolbarButton(
            onPressed: hasSelection ? () {
              pos.printOrder(order, isKitchenOnly: true);
              Get.snackbar("OK", "reprint_kitchen".tr, 
                backgroundColor: AppColors.primary, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
            } : null,
            icon: Icons.restaurant_menu_rounded,
            color: Colors.blueGrey,
            label: "reprint_kitchen".tr,
          ),
          const SizedBox(width: 8),
          _buildToolbarButton(
            onPressed: hasSelection ? () {
              pos.printOrder(order, receiptTitle: "HISOB CHEKI");
              pos.updateOrderStatus(order['id'], "Bill Printed");
              // Update local state to reflect status change immediately
              selectedOrder.value = {...order, 'status': 'Bill Printed'};
            } : null,
            icon: Icons.print_rounded,
            color: Colors.orange,
            label: "print_receipt".tr,
          ),
          const SizedBox(width: 8),
          if (status == "Bill Printed") ...[
            _buildToolbarButton(
              onPressed: hasSelection ? () => _handleOrderEdit(order, pos, catalog) : null,
              icon: Icons.payments_outlined,
              color: Colors.green,
              label: "pay".tr,
            ),
            if (pos.isAdmin || pos.isCashier) ...[
              const SizedBox(width: 8),
              _buildToolbarButton(
                onPressed: hasSelection ? () => _confirmUnlock(order['id'], pos) : null,
                icon: Icons.lock_open_rounded,
                color: Colors.orange,
                label: "unlock".tr,
              ),
            ],
          ] else ...[
            _buildToolbarButton(
              onPressed: isActive ? () => _handleOrderEdit(order, pos, catalog) : null,
              icon: Icons.edit_rounded,
              color: Colors.blue,
              label: "edit".tr,
            ),
          ],
          if (isActive && (order?['mode'] == "Dine-in" || order?['mode'] == null)) ...[
            const SizedBox(width: 8),
            _buildToolbarButton(
              onPressed: () => _showChangeTableDialog(context, order, pos),
              icon: Icons.sync_alt_rounded,
              color: Colors.purple,
              label: "Stolni o'zgartirish",
            ),
          ],
          if (pos.isAdmin || pos.isCashier) ...[
            const SizedBox(width: 8),
            _buildToolbarButton(
              onPressed: hasSelection ? () => _confirmDelete(order['id'], pos) : null,
              icon: Icons.delete_outline_rounded,
              color: Colors.red,
              label: "delete".tr,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    final bool isEnabled = onPressed != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleOrderEdit(Map<String, dynamic> order, POSController pos, List<FoodItem> catalog) {
    if (order['status'] == "Bill Printed") {
      if (!(pos.isAdmin || pos.isCashier)) {
        Get.snackbar("Xatolik", "Ushbu buyurtma cheki chiqarilgan (qulflangan)", 
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
    }

    final String? tableId = order['table'];
    if (tableId != null && tableId != "-" && pos.lockedTables.containsKey(tableId)) {
      final String? lockedBy = pos.lockedTables[tableId];
      if (lockedBy != (pos.currentUser.value?['name'] ?? "User")) {
        Get.snackbar("Xatolik", "Ushbu stolni hozirda $lockedBy tahrirlamoqda", 
            backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }
    }
    pos.loadOrderForEditing(order, catalog);
    Get.to(() => const HomeScreen());
  }

  void _showChangeTableDialog(BuildContext context, Map<String, dynamic> order, POSController pos) {
    if (order['status'] == "Bill Printed" && !(pos.isAdmin || pos.isCashier)) {
      Get.snackbar("Xatolik", "Cheki chiqarilgan buyurtmani stoli o'zgartirilmaydi", 
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final tableIdController = TextEditingController();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Stolni o'zgartirish", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Joriy stol: ${order['table'] ?? '-'}"),
            const SizedBox(height: 16),
            TextField(
              controller: tableIdController,
              decoration: InputDecoration(
                labelText: "Yangi stol raqami",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.text,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
          ElevatedButton(
            onPressed: () {
              final newTable = tableIdController.text.trim();
              if (newTable.isEmpty) {
                Get.snackbar("Xato", "Yangi stol raqamini kiriting", backgroundColor: Colors.orange, colorText: Colors.white);
                return;
              }
              pos.changeOrderTable(order['id'], newTable);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("O'zgartirish", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

