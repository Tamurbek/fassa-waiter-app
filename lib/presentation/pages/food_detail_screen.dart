import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import '../widgets/common_image.dart';

class FoodDetailScreen extends StatelessWidget {
  final FoodItem item;
  const FoodDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    var quantity = 1.obs;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Responsive(
        mobile: _buildMobileLayout(context, quantity),
        desktop: _buildDesktopLayout(context, quantity),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, RxInt quantity) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).size.height * 0.45,
          child: Hero(
            tag: 'food-image-${item.id}',
            child: CommonImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRoundButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Get.back(),
                  backgroundColor: const Color(0xFFFF9500),
                  iconColor: Colors.white,
                ),
                _buildRoundButton(icon: Icons.favorite_border, iconColor: Colors.red, onTap: () {}),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            width: double.infinity,
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(36))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  _buildItemHeader(),
                  const SizedBox(height: 32),
                  _buildDescription(),
                  const SizedBox(height: 32),
                  _buildQuantitySection(quantity),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
        _buildBottomBar(quantity),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, RxInt quantity) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Container(
          margin: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Hero(
                    tag: 'food-image-${item.id}',
                    child: CommonImage(imageUrl: item.imageUrl, fit: BoxFit.cover, height: double.infinity),
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                           _buildRoundButton(
                  icon: Icons.arrow_back_ios_new_rounded, 
                  onTap: () => Get.back(),
                  backgroundColor: const Color(0xFFFF9500),
                  iconColor: Colors.white,
                ),
                            _buildRoundButton(icon: Icons.favorite_border, iconColor: Colors.red, onTap: () {}),
                          ],
                        ),
                        const SizedBox(height: 40),
                        _buildItemHeader(isDesktop: true),
                        const SizedBox(height: 24),
                        _buildDescription(),
                        const SizedBox(height: 40),
                        _buildQuantitySection(quantity),
                        const Spacer(),
                        _buildBottomBar(quantity, isDesktop: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemHeader({bool isDesktop = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: TextStyle(fontSize: isDesktop ? 32 : 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.star, color: Colors.amber, size: 20), const SizedBox(width: 4), Text(item.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
            ],
          ),
        ),
        Text("${NumberFormat("#,###", "uz_UZ").format(item.price)} ${Get.find<POSController>().currencySymbol}", style: TextStyle(fontSize: isDesktop ? 34 : 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Text("${item.description}. Premium quality ingredients prepared for our POS terminal.", style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
      ],
    );
  }

  Widget _buildQuantitySection(RxInt quantity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quantity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQuantityButton(icon: Icons.add, onTap: () => quantity.value++, isPrimary: true),
            GestureDetector(
              onTap: () {
                final TextEditingController controller = TextEditingController(text: quantity.value.toString());
                Get.dialog(
                  AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text("quantity".tr),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
                      ElevatedButton(
                        onPressed: () {
                          final int? val = int.tryParse(controller.text);
                          if (val != null && val > 0) quantity.value = val;
                          Get.back();
                        },
                        child: Text("ok".tr),
                      ),
                    ],
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Obx(() => Text(
                  quantity.value.toString().padLeft(2, '0'), 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                )),
              ),
            ),
            _buildQuantityButton(icon: Icons.remove, onTap: () { if (quantity.value > 1) quantity.value--; }),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar(RxInt quantity, {bool isDesktop = false}) {
    final Widget button = ElevatedButton(
      onPressed: () {
        final pos = Get.find<POSController>();
        for (int i = 0; i < quantity.value; i++) {
          pos.addToCart(item);
        }
        Get.back();
      },
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, isDesktop ? 75 : 65), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long),
          const SizedBox(width: 12),
          const Text("Add to Bill", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Obx(() => Text("${NumberFormat("#,###", "uz_UZ").format(item.price * quantity.value)} ${Get.find<POSController>().currencySymbol}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (isDesktop) return button;

    return Positioned(
      bottom: 30,
      left: 24,
      right: 24,
      child: button,
    );
  }

  Widget _buildRoundButton({required IconData icon, Color? iconColor, Color? backgroundColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12), 
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.white, 
          borderRadius: BorderRadius.circular(14), 
          boxShadow: [
            BoxShadow(
              color: (backgroundColor ?? Colors.black).withOpacity(0.1), 
              blurRadius: 10, 
              offset: const Offset(0, 4)
            )
          ]
        ), 
        child: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 20)
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onTap, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12), // Increased from 8
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.white, 
          borderRadius: BorderRadius.circular(12), // Increased from 10
          border: isPrimary ? null : Border.all(color: Colors.grey.shade300)
        ), 
        child: Icon(icon, color: isPrimary ? Colors.white : AppColors.textPrimary, size: 26) // Increased from 20
      ),
    );
  }
}

