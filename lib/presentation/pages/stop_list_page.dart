import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/food_item.dart';
import '../widgets/common_image.dart';
import 'package:intl/intl.dart';

class StopListPage extends StatelessWidget {
  const StopListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Stop-list", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        final stopItems = pos.products.where((p) {
          if (pos.isStockTrackingEnabled.value) {
            return !p.isAvailable || p.isSoldOut;
          }
          return !p.isAvailable;
        }).toList();

        if (stopItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text("Hozircha hamma taomlar sotuvda bor", 
                  style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stopItems.length,
          itemBuilder: (context, index) {
            final item = stopItems[index];
            final String reason = !item.isAvailable ? "Admin tomonidan o'chirilgan" : "Tugadi (0 porsiya)";
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CommonImage(imageUrl: item.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: !item.isAvailable ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                reason, 
                                style: TextStyle(
                                  color: !item.isAvailable ? Colors.red : Colors.orange, 
                                  fontSize: 12, 
                                  fontWeight: FontWeight.w600
                                )
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${NumberFormat("#,###", "uz_UZ").format(item.price)} ${pos.currencySymbol}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }
}
