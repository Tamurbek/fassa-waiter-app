import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import '../widgets/printing_overlay.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';
import 'table_selection_screen.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    var currentIndex = 0.obs;

    final List<Map<String, dynamic>> menuItems = [
      {"icon": Icons.home_rounded, "label": "home_page".tr, "page": const OrdersScreen()},
      {"icon": Icons.table_restaurant_rounded, "label": "tables".tr, "page": const TableSelectionScreen(isRoot: true)},
      {"icon": Icons.settings_rounded, "label": "settings".tr, "page": const SettingsScreen()},
    ];

    final filteredMenu = menuItems; 

    return Obx(() => Stack(
      children: [
        Responsive(
          mobile: Scaffold(
            body: IndexedStack(
              index: currentIndex.value,
              children: filteredMenu.map<Widget>((e) => e['page'] as Widget).toList(),
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(filteredMenu.length, (index) {
                    return _buildMobileNavItem(index, currentIndex, filteredMenu[index]['icon'] as IconData);
                  }),
                ),
              ),
            ),
          ),
          desktop: Scaffold(
            body: Row(
              children: [
                _buildPremiumSidebar(currentIndex, filteredMenu, pos),
                Expanded(
                  child: IndexedStack(
                    index: currentIndex.value,
                    children: filteredMenu.map<Widget>((e) => e['page'] as Widget).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (pos.subscriptionDaysLeft.value != null && 
            pos.subscriptionDaysLeft.value! <= 3 && 
            pos.subscriptionDaysLeft.value! >= 0)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            width: Responsive.isMobile(context) ? null : 350,
            child: _buildSubscriptionBanner(pos),
          ),

        if (pos.isPrinting.value) const PrintingOverlay(),
      ],
    ));
  }

  Widget _buildPremiumSidebar(RxInt currentIndex, List<Map<String, dynamic>> items, POSController pos) {
    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.fastfood, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => Text(
                      pos.restaurantName.value.isEmpty ? "Fayz" : pos.restaurantName.value, 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF1A1A1A))
                    )),
                    Text("waiter_app".tr, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSel = currentIndex.value == index;
                return GestureDetector(
                  onTap: () => currentIndex.value = index,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFFFF7ED) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(item['icon'] as IconData, color: isSel ? const Color(0xFFFF9500) : const Color(0xFF9CA3AF), size: 22),
                        const SizedBox(width: 12),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            color: isSel ? const Color(0xFFFF9500) : const Color(0xFF6B7280),
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildSidebarProfile(pos),
        ],
      ),
    );
  }

  Widget _buildSidebarProfile(POSController pos) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFEDD5),
            child: Icon(Icons.person, color: Color(0xFFFF9500), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(pos.currentUser.value?['name'] ?? "Unknown", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(pos.currentUser.value?['role'] ?? "Noma'lum", 
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.lock_person_rounded, color: AppColors.primary),
            tooltip: "Terminalni qulflash",
            onPressed: () => pos.lockTerminal(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner(POSController pos) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Obuna tugashiga ${pos.subscriptionDaysLeft.value} kun qoldi', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 14)),
                  Text('Cheklovlar oldini olish uchun uzaytiring', 
                    style: TextStyle(color: Colors.orange.shade800.withOpacity(0.8), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
