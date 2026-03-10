import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'pos_controller_state.dart';
import '../../data/models/food_item.dart';

mixin StaffMixin on POSControllerState {
  void callWaiter(Map<String, dynamic> waiter) {
    if (!isAdmin && !isCashier) return;
    socket.emitCallWaiter({
      'waiter_id': waiter['id'],
      'waiter_name': waiter['name'],
      'sender_name': currentUser.value?['name'] ?? "Admin",
      'message': "Tezda kassa yoniga keling",
    });
    Get.snackbar("Signal yuborildi", "${waiter['name']}ga signal yuborildi", backgroundColor: Colors.blue, colorText: Colors.white);
  }

  Future<void> addUser(Map<String, dynamic> userData) async {
    final newUser = await api.createUser(userData);
    users.add(newUser);
    storage.write('all_users', users.toList());
  }

  Future<void> updateUserProfile(String id, Map<String, dynamic> userData) async {
    final updatedUser = await api.updateUser(id, userData);
    int index = users.indexWhere((u) => u['id'] == id);
    if (index != -1) {
      users[index] = updatedUser;
      users.refresh();
      storage.write('all_users', users.toList());
    }
  }

  Future<void> deleteUser(String id) async {
    await api.deleteUser(id);
    users.removeWhere((u) => u['id'] == id);
    storage.write('all_users', users.toList());
  }

  void showWaiterSelectionDialog(String tableId, Function onSelected) {
    if (users.isEmpty) { onSelected(); return; }
    final waiters = users.where((u) => u['role'] == "WAITER").toList();
    if (waiters.isEmpty) { onSelected(); return; }
    bool didSelect = false;
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Afitsantni tanlang", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: waiters.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final w = waiters[index];
              return ListTile(
                leading: CircleAvatar(child: Text(w['name']?[0] ?? "W")),
                title: Text(w['name'] ?? "Unknown"),
                onTap: () {
                  selectedWaiter.value = w['name'];
                  selectedWaiterId.value = w['id']?.toString();
                  didSelect = true;
                  Get.back();
                  onSelected();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              selectedWaiter.value = null;
              selectedWaiterId.value = null;
              didSelect = true;
              Get.back();
              onSelected();
            },
            child: const Text("O'zimga biriktirish"),
          ),
        ],
      ),
    ).then((_) {
      if (!didSelect) clearCurrentOrder();
    });
  }
}
