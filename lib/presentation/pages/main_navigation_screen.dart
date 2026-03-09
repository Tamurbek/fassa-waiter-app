import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import 'table_selection_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';
import 'stop_list_page.dart';
import '../../theme/app_theme.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();


    final List<Map<String, dynamic>> menuItems = [
      {"icon": Icons.table_restaurant_rounded, "label": "tables".tr, "page": const TableSelectionScreen(isRoot: true)},
      {"icon": Icons.assignment_rounded, "label": "orders".tr, "page": const OrdersScreen()},
      {"icon": Icons.block_flipped, "label": "Stop-list", "page": const StopListPage()},
      {"icon": Icons.settings_rounded, "label": "settings".tr, "page": const SettingsScreen()},
    ];

    return Obx(() => Scaffold(
      body: IndexedStack(
        index: pos.navIndex.value,

        children: menuItems.map<Widget>((e) => e['page'] as Widget).toList(),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(menuItems.length, (index) {
              return _buildMobileNavItem(index, pos.navIndex, menuItems[index]['icon'] as IconData);

            }),
          ),
        ),
      ),
    ));
  }

  Widget _buildMobileNavItem(int index, RxInt currentIndex, IconData icon) {
    return Obx(() {
      final isSel = currentIndex.value == index;
      return GestureDetector(
        onTap: () => currentIndex.value = index,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSel ? const Color(0xFFFF9500) : const Color(0xFF9CA3AF), size: 26),
            if (isSel)
              Container(margin: const EdgeInsets.only(top: 4), width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFFFF9500), shape: BoxShape.circle)),
          ],
        ),
      );
    });
  }
}
