import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../logic/pos_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("settings".tr, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Color(0xFF1A1A1A))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildProfileCard(pos),
              const SizedBox(height: 32),
              
              // No admin settings in Waiter app


              // No restaurant info editing in Waiter app


              const SizedBox(height: 24),
              _buildSectionLabel("system".tr),
              _buildSettingsCard([
                _buildActionItem(
                  Icons.language_rounded, 
                  "language".tr, 
                  trailingText: Get.locale?.languageCode == 'uz' ? "O'zbekcha" : (Get.locale?.languageCode == 'ru' ? "Русский" : "English"), 
                  onTap: () => _showLanguageSwitcher(context)
                ),

                _buildActionItem(Icons.info_rounded, "app_version".tr, trailingText: "v1.0.5", onTap: () {}),
              ]),
              
              const SizedBox(height: 48),
              _buildLogoutButton(pos),
              const SizedBox(height: 24),
              _buildFooter(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(POSController pos) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFFF9500),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                pos.restaurantName.value.isNotEmpty ? pos.restaurantName.value.substring(0, 1).toUpperCase() : "C",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(pos.restaurantName.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 4),
                    Obx(() => Text(pos.restaurantAddress.value, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500))),
                  ],
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final isVip = pos.isVip.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFFF9500)),
                        const SizedBox(width: 6),
                        Text(
                          isVip ? "VIP — CHEKSIZ OBUNA" : "STANDART PLAN",
                          style: const TextStyle(color: Color(0xFFFF9500), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF), letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          if (index == children.length - 1) return children[index];
          return Column(
            children: [
              children[index],
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: Color(0xFFF3F4F6)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, {String? trailingText, bool isDestructive = false, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF4B5563), size: 18),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) 
            Text(trailingText, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          if (isDestructive) 
            const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.redAccent)
          else 
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(POSController pos) {
    return Center(
      child: TextButton.icon(
        onPressed: () => pos.logout(),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: Text("logout".tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent,
          backgroundColor: const Color(0xFFFFF1F2),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        "© 2024 Fayz FoodTech Cloud Services",
        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Sizning tilingiz / Ваш язык / Your Language", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            _buildLangItem("O'zbekcha", 'uz', 'UZ'),
            _buildLangItem("English", 'en', 'US'),
            _buildLangItem("Русский", 'ru', 'RU'),
          ],
        ),
      ),
    );
  }

  Widget _buildLangItem(String label, String langCode, String countryCode) {
    final bool isSelected = Get.locale?.languageCode == langCode;
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? const Color(0xFFFF9500) : const Color(0xFF1A1A1A))),
      onTap: () {
        final locale = Locale(langCode, countryCode);
        Get.updateLocale(locale);
        GetStorage().write('lang', '${langCode}_$countryCode');
        Get.back();
      },
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF9500)) : null,
    );
  }
}
