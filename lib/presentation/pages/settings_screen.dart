import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final storage = GetStorage();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("settings".tr, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Theme.of(context).textTheme.displayLarge?.color)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildProfileCard(context, pos),
              const SizedBox(height: 32),
              
              _buildSectionLabel("Appearance"),
              _buildSettingsCard(context, [
                Obx(() => _buildToggleItem(
                  Icons.dark_mode_rounded, 
                  "Tungi rejim", 
                  pos.isDarkMode.value, 
                  (val) => pos.toggleTheme()
                )),
              ]),

              const SizedBox(height: 24),
              _buildSectionLabel("system".tr),
              _buildSettingsCard(context, [
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

  Widget _buildProfileCard(BuildContext context, POSController pos) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                pos.restaurantName.value.isNotEmpty ? pos.restaurantName.value.substring(0, 1).toUpperCase() : "W",
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() => Text(pos.restaurantName.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.displayLarge?.color))),
                const SizedBox(height: 4),
                Text(pos.currentUser.value?['name'] ?? "Waiter", style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500)),
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

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
    return Builder(
      builder: (context) {
        return ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Theme.of(context).iconTheme.color?.withOpacity(0.7) ?? const Color(0xFF4B5563), size: 18),
          ),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
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
    );
  }

  Widget _buildToggleItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Builder(
      builder: (context) {
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).cardColor.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Theme.of(context).iconTheme.color?.withOpacity(0.7) ?? const Color(0xFF4B5563), size: 18),
          ),
          title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyLarge?.color)),
          trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF9500),
            activeTrackColor: const Color(0xFFFF9500).withOpacity(0.2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }
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
        "© 2026 Fassa POS",
        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
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
