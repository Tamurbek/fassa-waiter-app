import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import 'home_screen.dart';

class TableSelectionScreen extends StatefulWidget {
  final bool isRoot;
  const TableSelectionScreen({super.key, this.isRoot = false});

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final bool isMobile = Responsive.isMobile(context);

    return Obx(() {
      final List<String> locations = pos.tableAreas.toList();
      
      return DefaultTabController(
        length: locations.length,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text("select_table".tr),
            centerTitle: true,
            leading: widget.isRoot ? null : Padding(
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
            actions: [
              if (pos.isAdmin)
                IconButton(
                  icon: Icon(pos.isEditMode.value ? Icons.check_circle : Icons.edit_location_alt_rounded),
                  onPressed: () => pos.toggleEditMode(),
                  color: pos.isEditMode.value ? Colors.green : null,
                  tooltip: pos.isEditMode.value ? "save_layout".tr : "edit_layout".tr,
                ),
              IconButton(
                icon: const Icon(Icons.lock_rounded, color: Colors.orange),
                onPressed: () => pos.lockTerminal(),
                tooltip: "Terminalni qulflash",
              ),
            ],
            bottom: TabBar(
              isScrollable: locations.length > 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: locations.map((loc) => Tab(text: loc.toLowerCase().tr)).toList(),
            ),
          ),
          body: Center(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         _StatusIndicator(color: Colors.green, label: "available".tr),
                         const SizedBox(width: 24),
                         _StatusIndicator(color: Colors.red, label: "occupied".tr),
                         const SizedBox(width: 24),
                         _StatusIndicator(color: Colors.orange, label: "editing_status".tr),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: locations.map((location) {
                        return _FloorPlanView(
                          location: location,
                          tables: pos.tablesByArea[location] ?? [],
                          pos: pos,
                        );
                      }).toList(),
                    ),
                  ),
                  Obx(() => pos.isEditMode.value 
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        color: Colors.amber.withOpacity(0.1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text("dragging_tip".tr, style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : const SizedBox.shrink()
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _FloorPlanView extends StatelessWidget {
  final String location;
  final List<String> tables;
  final POSController pos;

  const _FloorPlanView({
    required this.location,
    required this.tables,
    required this.pos,
  });

  @override
  Widget build(BuildContext context) {
    // Show simplified grid view only on mobile phones
    if (Responsive.isMobile(context)) {
      return GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 100,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: tables.length,
        itemBuilder: (context, index) {
          final tableNum = tables[index];
          final String tableId = "$location-$tableNum";

          return Obx(() {
            final bool isOccupied = pos.allOrders.any((o) => 
              o['table'] == tableId && 
              !["Completed", "Cancelled"].contains(o['status'])
            );

            final String? lockedByUser = pos.lockedTables[tableId];
            final bool isLockedByMe = lockedByUser != null && lockedByUser == (pos.currentUser.value?['name'] ?? "User");
            final bool isLockedByOther = lockedByUser != null && !isLockedByMe;

            return GestureDetector(
              onTap: isLockedByOther ? () {
                Get.snackbar("Xatolik", "Ushbu stolni hozirda $lockedByUser tahrirlamoqda", 
                  backgroundColor: Colors.orange, colorText: Colors.white);
              } : () {
                if (isOccupied) {
                  final order = pos.allOrders.firstWhereOrNull((o) => 
                    o['table'] == tableId && 
                    !["Completed", "Cancelled"].contains(o['status'])
                  );
                  if (order != null) {
                    if (order['status'] == "Bill Printed" && !(pos.isAdmin || pos.isCashier)) {
                      Get.snackbar("Xatolik", "Ushbu buyurtma cheki chiqarilgan (qulflangan)", 
                          backgroundColor: Colors.red, colorText: Colors.white);
                      return;
                    }
                    pos.loadOrderForEditing(order, pos.products);
                    Get.to(() => const HomeScreen());
                  }
                } else {
                  if (pos.isWaiter && !pos.allowWaiterMobileOrders.value && pos.currentTerminal.value == null) {
                    Get.snackbar("Ruxsat berilmagan", "Shaxsiy telefondan buyurtma olish taqiqlangan. Iltimos, POS terminaldan foydalaning.", 
                      backgroundColor: Colors.red, colorText: Colors.white);
                    return;
                  }
                  pos.setTable(tableId);
                  Get.to(() => const HomeScreen());
                }
              },
              child: _TableWidget(
                tableNum: tableNum,
                isOccupied: isOccupied,
                isEditMode: false,
                lockedByUser: lockedByUser,
                isLockedByOther: isLockedByOther,
              ),
            );
          });
        },
      );
    }

    // Show custom floor plan for Terminal/Desktop/Tablet
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxTableX = constraints.maxWidth;
        double maxTableY = constraints.maxHeight;
        
        for (var tableNum in tables) {
          final String tableId = "$location-$tableNum";
          final posData = pos.tablePositions[tableId];
          if (posData != null) {
             final props = pos.tableProperties[tableId] ?? {};
             double w = (props['width'] as num?)?.toDouble() ?? 80.0;
             double h = (props['height'] as num?)?.toDouble() ?? 80.0;
             if (posData['x']! + w > maxTableX) maxTableX = posData['x']! + w + 200;
             if (posData['y']! + h > maxTableY) maxTableY = posData['y']! + h + 200;
          }
        }

        final areaDetails = pos.tableAreaDetails[location];
        final String dimText = areaDetails != null 
            ? "${areaDetails['width_m']}m x ${areaDetails['height_m']}m" 
            : "";

        return Obx(() => InteractiveViewer(
          boundaryMargin: const EdgeInsets.all(1000),
          minScale: 0.1,
          maxScale: 2.5,
          panEnabled: !pos.isEditMode.value, 
          child: Container(
            width: maxTableX,
            height: maxTableY,
            color: Colors.grey.withOpacity(0.02),
            child: Stack(
              children: [
                if (dimText.isNotEmpty)
                  Positioned(
                    right: 20, bottom: 20,
                    child: GestureDetector(
                      onTap: pos.isAdmin ? () => _showAreaSettingsDialog(context) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(dimText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                            if (pos.isAdmin) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.settings, size: 14, color: Colors.grey.shade600),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ...tables.map((tableNum) {
                  final String tableId = "$location-$tableNum";
                  final position = pos.tablePositions[tableId] ?? _getDefaultPosition(tableNum, maxTableX, maxTableY);
                  final Map<String, dynamic> props = pos.tableProperties[tableId] ?? {};
                  final double tableWidth = (props['width'] as num?)?.toDouble() ?? 80.0;
                  final double tableHeight = (props['height'] as num?)?.toDouble() ?? 80.0;
                  final String tableShape = props['shape']?.toString() ?? "square";

                  final bool isOccupied = pos.allOrders.any((o) => 
                    o['table'] == tableId && 
                    !["Completed", "Cancelled"].contains(o['status'])
                  );

                  final String? lockedByUser = pos.lockedTables[tableId];
                  final bool isLockedByMe = lockedByUser != null && lockedByUser == (pos.currentUser.value?['name'] ?? "User");
                  final bool isLockedByOther = lockedByUser != null && !isLockedByMe;

                  return Positioned(
                    left: position['x']!,
                    top: position['y']!,
                    child: GestureDetector(
                      onPanUpdate: pos.isEditMode.value ? (details) {
                        double newX = position['x']! + details.delta.dx;
                        double newY = position['y']! + details.delta.dy;
                        newX = newX.clamp(0.0, maxTableX - tableWidth);
                        newY = newY.clamp(0.0, maxTableY - tableHeight);
                        pos.updateTablePosition(tableId, newX, newY);
                      } : null,
                      onPanEnd: pos.isEditMode.value ? (_) {
                        pos.syncTablePositionWithBackend(tableId);
                      } : null,
                      onTap: pos.isEditMode.value ? null : (isLockedByOther ? () {
                        Get.snackbar("Xatolik", "Ushbu stolni hozirda $lockedByUser tahrirlamoqda", 
                          backgroundColor: Colors.orange, colorText: Colors.white);
                      } : () {
                        if (isOccupied) {
                          final order = pos.allOrders.firstWhereOrNull((o) => 
                            o['table'] == tableId && 
                            !["Completed", "Cancelled"].contains(o['status'])
                          );
                          if (order != null) {
                            if (order['status'] == "Bill Printed" && !(pos.isAdmin || pos.isCashier)) {
                              Get.snackbar("Xatolik", "Ushbu buyurtma cheki chiqarilgan (qulflangan)", 
                                  backgroundColor: Colors.red, colorText: Colors.white);
                              return;
                            }
                            pos.loadOrderForEditing(order, pos.products);
                            Get.to(() => const HomeScreen());
                          }
                        } else {
                          // Check mobile orders permission for waiters if they are on a personal phone
                          // (Even though floor plan usually shown on tablet/desktop, we keep permission check consistent)
                          if (pos.isWaiter && !pos.allowWaiterMobileOrders.value && pos.currentTerminal.value == null) {
                            Get.snackbar("Ruxsat berilmagan", "Shaxsiy telefondan buyurtma olish taqiqlangan.", 
                              backgroundColor: Colors.red, colorText: Colors.white);
                            return;
                          }

                          pos.setTable(tableId);
                          if (pos.isAdmin || pos.isCashier) {
                            pos.showWaiterSelectionDialog(tableId, () {
                              Get.to(() => const HomeScreen());
                            });
                          } else {
                            pos.selectedWaiter.value = null;
                            Get.to(() => const HomeScreen());
                          }
                        }
                      }),
                      child: _TableWidget(
                        tableNum: tableNum,
                        isOccupied: isOccupied,
                        isEditMode: pos.isEditMode.value,
                        lockedByUser: lockedByUser,
                        isLockedByOther: isLockedByOther,
                        width: tableWidth,
                        height: tableHeight,
                        shape: tableShape,
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ));
      },
    );
  }

  void _showAreaSettingsDialog(BuildContext context) {
    final areaDetails = pos.tableAreaDetails[location];
    final wController = TextEditingController(text: areaDetails?['width_m']?.toString() ?? "10.0");
    final hController = TextEditingController(text: areaDetails?['height_m']?.toString() ?? "10.0");

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("$location - O'lchamlar", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Kenglik (metr)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Uzunlik (metr)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () {
              final w = double.tryParse(wController.text) ?? 10.0;
              final h = double.tryParse(hController.text) ?? 10.0;
              pos.updateAreaDimensions(location, w, h);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  Map<String, double> _getDefaultPosition(String tableNum, double width, double height) {
    // Extract numbers if possible, otherwise use hash
    int? parsed = int.tryParse(tableNum.replaceAll(RegExp(r'[^0-9]'), ''));
    int index = (parsed ?? tableNum.hashCode.abs()) % 20;
    
    int cols = (width / 100).floor().clamp(1, 10);
    double x = (index % cols) * 100.0 + 20;
    double y = (index ~/ cols) * 100.0 + 20;
    return {"x": x, "y": y};
  }
}

class _TableWidget extends StatelessWidget {
  final String tableNum;
  final bool isOccupied;
  final bool isEditMode;
  final String? lockedByUser;
  final bool isLockedByOther;
  final double width;
  final double height;
  final String shape;

  const _TableWidget({
    required this.tableNum,
    required this.isOccupied,
    required this.isEditMode,
    this.lockedByUser,
    this.isLockedByOther = false,
    this.width = 80.0,
    this.height = 80.0,
    this.shape = "square",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isLockedByOther 
            ? Colors.orange.withOpacity(0.1) 
            : (isOccupied ? Colors.red.withOpacity(0.1) : (isEditMode ? Colors.blue.withOpacity(0.05) : AppColors.white)),
        shape: shape == 'circle' ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: shape == 'circle' ? null : BorderRadius.circular(20),
        border: Border.all(
          color: isEditMode 
              ? Colors.blue.withOpacity(0.5) 
              : (isLockedByOther ? Colors.orange.withOpacity(0.5) : (isOccupied ? Colors.red.withOpacity(0.3) : Colors.grey.shade200)),
          width: (isEditMode || isLockedByOther) ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isEditMode ? Icons.drag_indicator : (isLockedByOther ? Icons.lock_clock_rounded : Icons.table_restaurant), 
            color: isEditMode 
                ? Colors.blue 
                : (isLockedByOther ? Colors.orange : (isOccupied ? Colors.red : AppColors.primary)),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            tableNum,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isLockedByOther ? Colors.orange : (isOccupied ? Colors.red : AppColors.textPrimary),
            ),
          ),
          if (isLockedByOther)
            Text(
              lockedByUser ?? "User",
              style: const TextStyle(fontSize: 8, color: Colors.orange, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else if (isOccupied && !isEditMode)
            Text(
              "occupied".tr,
              style: const TextStyle(fontSize: 8, color: Colors.red),
            ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}


