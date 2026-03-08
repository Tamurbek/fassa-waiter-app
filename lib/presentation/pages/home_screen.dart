import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import 'food_detail_screen.dart';
import 'cart_screen.dart';
import '../widgets/common_image.dart';
import '../widgets/printing_overlay.dart';
import 'package:intl/intl.dart';
import 'main_navigation_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final bool isMobile = Responsive.isMobile(context);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) pos.clearCurrentOrder();
      },
      child: Obx(() => Stack(
        children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          body: Stack(
            children: [
              Column(
                children: [
                  _buildGeofenceBanner(pos),
                  _buildTopBar(pos, context),
                  _buildCategories(pos, context),
                  Expanded(
                    child: Obx(() {
                      return Column(
                        children: [
                          Expanded(child: _buildItemsGrid(pos.filteredProducts, context)),
                          // Extra padding for bottom bar
                          if (!isMobile && pos.currentOrder.isNotEmpty)
                            const SizedBox(height: 90),
                        ],
                      );
                    }),
                  ),
                ],
              ),
              // Bottom Order Bar for Tablet
              if (!isMobile)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Obx(() => pos.currentOrder.isEmpty 
                    ? const SizedBox.shrink()
                    : _buildDesktopBottomBar(pos, context)),
                ),
            ],
          ),
          bottomNavigationBar: isMobile && pos.currentOrder.isNotEmpty 
            ? _buildMobileCartButton(pos, context) 
            : null,
        ),
        if (pos.isPrinting.value) const PrintingOverlay(),
      ],
    )));
  }

  Widget _buildTopBar(POSController pos, BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 40, 
        MediaQuery.of(context).padding.top + 12, 
        isMobile ? 16 : 40, 
        12
      ),
      child: _isSearching && isMobile
        ? Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    pos.searchQuery.value = "";
                  });
                },
              ),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (val) => pos.searchQuery.value = val,
                    decoration: InputDecoration(
                      hintText: 'search_hint'.tr,
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 18),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              pos.searchQuery.value = "";
                            },
                          ) 
                        : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          )
        : Row(
            children: [
              if (Navigator.canPop(context)) ...[
                GestureDetector(
                  onTap: () {
                    pos.clearCurrentOrder();
                    Get.back();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9500),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9500).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "back".tr,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              
              if (isMobile) 
                const Spacer()
              else ...[
                Obx(() => Text(
                  pos.restaurantName.value.isEmpty ? "FASSA" : pos.restaurantName.value.toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF9500), letterSpacing: -0.5),
                )),
                const SizedBox(width: 32),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => pos.searchQuery.value = val,
                      decoration: InputDecoration(
                        hintText: 'search_hint'.tr,
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                        suffixIcon: Obx(() => pos.searchQuery.value.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 20, color: Color(0xFF9CA3AF)),
                              onPressed: () {
                                _searchController.clear();
                                pos.searchQuery.value = "";
                              },
                            ) 
                          : const SizedBox.shrink()),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              if (isMobile) ...[
                _buildTopIcon(Icons.search, onTap: () => setState(() => _isSearching = true)),
                const SizedBox(width: 8),
              ],
              _buildTopIcon(Icons.notifications_outlined),
              const SizedBox(width: 8),
              _buildMoreActionsMenu(pos, context),
            ],
          ),
    );
  }

  Widget _buildMoreActionsMenu(POSController pos, BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.more_horiz_rounded, color: Color(0xFF1A1A1A), size: 22),
      ),
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'lock':
            pos.lockTerminal();
            break;
          case 'refresh':
            pos.refreshData();
            break;
          case 'settings':
            Get.toNamed('/settings');
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'lock',
          child: _buildPopupItem(Icons.lock_outline_rounded, "lock_terminal".tr),
        ),
        PopupMenuItem(
          value: 'refresh',
          child: _buildPopupItem(Icons.refresh_rounded, "refresh_data".tr),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'settings',
          child: _buildPopupItem(Icons.settings_outlined, "settings".tr),
        ),
      ],
    );
  }

  Widget _buildPopupItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTopIcon(IconData icon, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF1A1A1A), size: 22),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildCategories(POSController pos, BuildContext context) {
    final List<Map<String, dynamic>> catItems = pos.categories.map((cat) {
      IconData icon = Icons.grid_view_rounded;
      final name = cat.toLowerCase();
      if (name.contains('burger')) icon = Icons.lunch_dining_rounded;
      if (name.contains('drink') || name.contains('ichimlik')) icon = Icons.local_drink_rounded;
      if (name.contains('pizza') || name.contains('pitsa')) icon = Icons.local_pizza_rounded;
      if (name.contains('lavash')) icon = Icons.local_fire_department_rounded;
      if (name.contains('salat') || name.contains('salad')) icon = Icons.eco_rounded;
      if (name.contains('desert') || name.contains('dessert')) icon = Icons.cake_rounded;
      
      return {
        "name": cat,
        "label": cat == "All" ? "all".tr : cat,
        "icon": icon
      };
    }).toList();

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: Responsive.isMobile(context) ? 24 : 40),
        scrollDirection: Axis.horizontal,
        itemCount: catItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = catItems[index];
          return Obx(() {
            final isSelected = pos.selectedCategory.value == cat['name'] as String;
            return GestureDetector(
              onTap: () => pos.selectedCategory.value = cat['name'] as String,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF9500) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? Colors.transparent : Colors.grey.shade200),
                  boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFFF9500).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                ),
                child: Row(
                  children: [
                    Icon(cat['icon'] as IconData, size: 18, color: isSelected ? Colors.white : const Color(0xFF1A1A1A)),
                    const SizedBox(width: 8),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildItemsGrid(List<FoodItem> items, BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildFoodCard(items[index], context),
    );
  }

  Widget _buildFoodCard(FoodItem item, BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final bool isMobile = Responsive.isMobile(context);

    return GestureDetector(
      onTap: () {
        if (item.hasVariants || item.variants.isNotEmpty) {
          _showVariantPicker(context, item, pos);
        } else {
          pos.addToCart(item);
        }
      },
      onLongPress: () {
        if (item.hasVariants && item.variants.isNotEmpty) {
          _showVariantPicker(context, item, pos);
          return;
        }
        for (int i = 0; i < 5; i++) {
          pos.addToCart(item);
        }
        Get.snackbar(
          "Tezkor qo'shish", 
          "${item.name}dan 5 ta qo'shildi",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.withOpacity(0.8),
          colorText: Colors.white,
          duration: const Duration(seconds: 1),
        );
      },
      child: Obx(() {
        final int qty = pos.currentOrder
            .where((e) => (e['item'] as FoodItem).id == item.id && e['isNew'] == true)
            .fold(0, (sum, e) => sum + (e['quantity'] as int));

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 4))],
              ),
              child: Opacity(
                opacity: (item.isSoldOut || !item.isAvailable) ? 0.6 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        width: double.infinity,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CommonImage(imageUrl: item.imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                            ),
                            // Freshness Badge
                            if (pos.isStockTrackingEnabled.value && item.isFresh)
                              Positioned(
                                top: 8, left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                                  child: const Text("Yangi", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            // Low Stock Badge
                            if (pos.isStockTrackingEnabled.value && item.isLowStock)
                              Positioned(
                                bottom: 8, right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                                  child: Text("${item.stockRemaining} qoldi", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            // Sold Out Overlay
                            if (!item.isAvailable || (pos.isStockTrackingEnabled.value && item.isSoldOut))
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(16)),
                                  child: const Center(
                                    child: Text("TUGADI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)), 
                            maxLines: 1, overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.hasVariants && item.variants.isNotEmpty)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Variantlar",
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: Color(0xFF0EA5E9))),
                                          Text("${NumberFormat("#,###", "uz_UZ").format(item.variants.first.price)} ${pos.currencySymbol}", 
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFFF9500))),
                                        ],
                                      )
                                    else
                                      Text("${NumberFormat("#,###", "uz_UZ").format(item.price)} ${pos.currencySymbol}", 
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFFFF9500))),
                                  ],
                                ),
                              ),
                              if (isMobile && qty == 0 && (item.isAvailable && (!pos.isStockTrackingEnabled.value || !item.isSoldOut)))
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: item.hasVariants ? const Color(0xFFE0F2FE) : const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  child: Icon(
                                    item.hasVariants ? Icons.expand_more : Icons.add,
                                    color: item.hasVariants ? const Color(0xFF0EA5E9) : const Color(0xFFFF9500),
                                    size: 18
                                  ),
                                ),
                            ],
                          ),
                          if (isMobile && qty > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Center(child: _buildCounterControl(item, qty, pos)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (qty > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9500).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    "$qty",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  void _showVariantPicker(BuildContext context, FoodItem item, POSController pos) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            Text("Hajmni tanlang:", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: item.variants.where((v) => v.isAvailable).map((variant) => Obx(() {
                    final int qty = pos.currentOrder
                        .where((e) => (e['item'] as FoodItem).id == item.id && 
                                     e['variant']?.id == variant.id && 
                                     e['isNew'] == true)
                        .fold(0, (sum, e) => sum + (e['quantity'] as int));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: qty > 0 ? const Color(0xFFFFF7ED) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: qty > 0 ? const Color(0xFFFF9500).withOpacity(0.5) : const Color(0xFFEDF0F5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(variant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  "${NumberFormat('#,###', 'uz_UZ').format(variant.price)} ${pos.currencySymbol}",
                                  style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          _buildCounterForVariant(item, variant, qty, pos),
                        ],
                      ),
                    );
                  })).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Tayyor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterForVariant(FoodItem item, dynamic variant, int qty, POSController pos) {
    if (qty == 0) {
      return GestureDetector(
        onTap: () => pos.addToCart(item, variant: variant),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.add, color: Color(0xFF0EA5E9), size: 20),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => pos.addToCart(item, variant: variant),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, size: 22, color: Colors.white),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            alignment: Alignment.center,
            child: Text("$qty", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          GestureDetector(
            onTap: () => pos.decrementFromCart(item, variant: variant),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.remove, size: 22, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterControl(FoodItem item, int qty, POSController pos) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => pos.addToCart(item),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, size: 22, color: Colors.white),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            alignment: Alignment.center,
            child: Text("$qty", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          GestureDetector(
            onTap: () => pos.decrementFromCart(item),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.remove, size: 22, color: Color(0xFF1A1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOSCartSidebar(POSController pos, BuildContext context) {
    return Column(
      children: [
        _buildOperatorHeader(pos),
        _buildModeSelector(pos),
        Expanded(
          child: pos.currentOrder.isEmpty
              ? _buildEmptyCartPlaceholder()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: pos.currentOrder.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final cartItem = pos.currentOrder[index];
                    return _buildPOSCartItem(cartItem, index, pos);
                  },
                ),
        ),
        _buildPOSOrderSummary(pos),
      ],
    );
  }

  Widget _buildOperatorHeader(POSController pos) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFEDD5),
            child: Icon(Icons.person, color: Color(0xFFFF9500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("operator".tr, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
                Text((pos.currentUser.value?['name'] as String?) ?? "Unknown", 
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
          if (pos.isAdmin || pos.isCashier)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
              onPressed: () {
                Get.dialog(
                  AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text("cancel_order_confirm_title".tr),
                    content: Text("cancel_order_confirm_msg".tr),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: Text("back".tr)),
                      TextButton(
                        onPressed: () {
                          pos.clearCurrentOrder();
                          Get.back();
                        }, 
                        child: Text("yes_cancel".tr, style: const TextStyle(color: Colors.red))
                      ),
                    ],
                  )
                );
              },
              tooltip: "Bekor",
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(POSController pos) {
    final modes = [
      {"id": "Dine-in", "label": "dine_in".tr, "icon": Icons.restaurant},
      {"id": "Takeaway", "label": "takeaway".tr, "icon": Icons.shopping_bag},
      {"id": "Delivery", "label": "delivery".tr, "icon": Icons.delivery_dining},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: modes.map((m) {
          final isSel = pos.currentMode.value == m['id'] as String;
          return Expanded(
            child: GestureDetector(
              onTap: () => pos.setMode(m['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSel ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : null,
                ),
                child: Column(
                  children: [
                    Icon(m['icon'] as IconData, size: 18, color: isSel ? const Color(0xFFFF9500) : const Color(0xFF9CA3AF)),
                    const SizedBox(height: 4),
                    Text(m['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF1A1A1A) : const Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPOSCartItem(Map<String, dynamic> cartItem, int index, POSController pos) {
    final FoodItem item = cartItem['item'];
    final int quantity = cartItem['quantity'];
    final bool isNew = cartItem['isNew'] == true;
    final int sentQty = cartItem['sentQty'] ?? 0;
    final bool isCancelled = !isNew && quantity == 0;
    final bool isPartialCancelled = !isNew && quantity < sentQty && quantity > 0;

    return Opacity(
      opacity: isCancelled ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNew 
            ? const Color(0xFFEFF6FF) // Light blue for new
            : (isCancelled ? Colors.grey.shade100 : const Color(0xFFF8F9FB)),
          borderRadius: BorderRadius.circular(20),
          border: isNew ? Border.all(color: Colors.blue.shade100) : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CommonImage(imageUrl: item.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                ),
                if (isCancelled)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.name, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          )
                        ),
                      ),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6)),
                          child: const Text("Yangi", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (isPartialCancelled)
                    Text("${sentQty - quantity} ta bekor qilindi", 
                      style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold))
                  else if (isCancelled)
                    const Text("Bekor qilingan", 
                      style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold))
                  else
                    Text(
                      () {
                        final variant = cartItem['variant'];
                        final price = variant?.price ?? item.price;
                        final variantLabel = variant != null ? " (${variant.name})" : "";
                        return "${item.name}$variantLabel — ${NumberFormat('#,###', 'uz_UZ').format(price)} ${pos.currencySymbol}";
                      }(),
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _buildVerticalCounter(index, quantity, pos, isCancelled),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalCounter(int index, int qty, POSController pos, bool isCancelled) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        border: Border.all(color: const Color(0xFFEDF0F5), width: 1.5)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCounterBtn(Icons.add, () => pos.updateQuantity(index, 1)),
          GestureDetector(
            onTap: () => pos.showQuantityDialog(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text("$qty", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isCancelled ? Colors.red : const Color(0xFF1A1A1A))),
            ),
          ),
          _buildCounterBtn(Icons.remove, () => pos.updateQuantity(index, -1)),
        ],
      ),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildPOSOrderSummary(POSController pos) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDF0F5))),
      ),
      child: Column(
        children: [
          _buildSumRow("subtotal_sum".tr, "${NumberFormat("#,###", "uz_UZ").format(pos.subtotal)} ${pos.currencySymbol}"),
          _buildSumRow(
          pos.currentMode.value == "Dine-in" 
            ? "${"service_fee_label".tr} (${pos.serviceFeeDineIn.value.toStringAsFixed(0)}%)"
            : "service_fee_label".tr, 
          "${NumberFormat("#,###", "uz_UZ").format(pos.serviceFee)} ${pos.currencySymbol}"
        ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("total".tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              Text("${NumberFormat("#,###", "uz_UZ").format(pos.total)} ${pos.currencySymbol}", 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF9500))),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Kitchen Print (Always visible)
              Expanded(
                child: _buildActionBtn(Icons.soup_kitchen_rounded, "Oshxona", const Color(0xFF3B82F6), () async {
                  if (!pos.isOrderModified.value) {
                    Get.snackbar("Eslatma", "Saqlash uchun o'zgarishlar kiritilmadi", 
                      backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  bool success = await pos.submitOrder(isPaid: false);
                  if (success) {
                    Get.offAll(() => const MainNavigationScreen());
                  }
                }, tooltip: "kitchen_print_sidebar".tr),
              ),
              const SizedBox(width: 8),
              // Receipt Print (Always visible)
              Expanded(
                child: _buildActionBtn(Icons.receipt_long_rounded, "Hisob", const Color(0xFF64748B), () {
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
                }, tooltip: "Hisob chekini chiqarish"),
              ),
              // Pay & Finish (Admin/Cashier only)
              if (pos.isAdmin || pos.isCashier) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionBtn(Icons.payments_rounded, "To`lov", const Color(0xFFFF9500), () async {
                    bool success = await pos.submitOrder(isPaid: true);
                    if (success) {
                      Get.offAll(() => const MainNavigationScreen());
                    }
                  }, tooltip: "pay_finish_sidebar".tr),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap, {String? tooltip}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip ?? label,
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label, 
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSidebarBtn(String label, Color color, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildEmptyCartPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined, size: 40, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),
          Text("current_bill_empty".tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          Text("empty_cart_msg".tr, 
            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMobileCartButton(POSController pos, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Get.bottomSheet(
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                        child: const CartScreen(),
                      ),
                    ),
                    isScrollControlled: true,
                    ignoreSafeArea: false,
                  ),
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_cart, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text("${pos.totalItems} ta mahsulot", style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text("${NumberFormat("#,###", "uz_UZ").format(pos.total)} ${pos.currencySymbol}", 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              ),
              Obx(() => ElevatedButton(
                onPressed: pos.isSubmitting.value ? null : () async {
                  if (!pos.isOrderModified.value) {
                    Get.snackbar("Eslatma", "Saqlash uchun o'zgarishlar kiritilmadi", 
                      backgroundColor: Colors.orange, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  bool success = await pos.submitOrder(isPaid: false);
                  if (success) {
                    Get.offAll(() => const MainNavigationScreen());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFFFF9500).withOpacity(0.6),
                ),
                child: pos.isSubmitting.value 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.soup_kitchen_rounded, size: 20),
                        const SizedBox(width: 8),
                        const Text("Oshxonaga", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeofenceBanner(POSController pos) {
    return Obx(() {
      if (pos.isWithinGeofence.value || !pos.isWaiter) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: Colors.red,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.location_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              "Hozirda hududdan tashqaridasiz!",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildDesktopBottomBar(POSController pos, BuildContext context) {
    return Container(
      height: 90,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Order Summary
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${pos.totalItems} ta mahsulot",
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                "${NumberFormat("#,###", "uz_UZ").format(pos.total)} ${pos.currencySymbol}",
                style: const TextStyle(color: Color(0xFFFF9500), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
            ],
          ),
          const Spacer(),
          // Action Buttons
          Row(
            children: [
              _buildBottomActionBtn(
                "Tozalash", 
                const Color(0xFFF3F4F6), 
                const Color(0xFFEF4444), 
                Icons.delete_sweep_rounded, 
                () => pos.clearCurrentOrder()
              ),
              const SizedBox(width: 16),
              _buildBottomActionBtn(
                "Ko'rish", 
                const Color(0xFFF3F4F6), 
                const Color(0xFF1A1A1A), 
                Icons.shopping_bag_outlined, 
                () => Get.to(() => const CartScreen())
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 56,
                width: 200,
                child: Obx(() => ElevatedButton(
                  onPressed: pos.isSubmitting.value ? null : () async {
                    bool success = await pos.submitOrder(isPaid: false);
                    if (success) {
                      Get.offAll(() => const MainNavigationScreen());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: pos.isSubmitting.value 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.soup_kitchen_rounded, size: 20),
                        const SizedBox(width: 10),
                        const Text("Oshxonaga", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBtn(String label, Color bg, Color text, IconData icon, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: text,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

