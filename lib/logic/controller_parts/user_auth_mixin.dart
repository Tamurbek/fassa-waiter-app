import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'pos_controller_state.dart';
import '../../presentation/pages/auth/terminal_selection_page.dart';
import '../../presentation/pages/auth/pin_code_screen.dart';
import '../../presentation/pages/auth/staff_selection_page.dart';

mixin UserAuthMixin on POSControllerState {
  void startSubscriptionCheck() {
    if (currentUser.value != null) {
      checkSubscription();
    }
    subscriptionTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (currentUser.value != null) {
        checkSubscription(showWarning: false);
      }
    });
  }

  void initLocationTracking() async {
    if (currentUser.value == null || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      if (Platform.isAndroid || Platform.isIOS) {
        FlutterBackgroundService().invoke("stopService");
      }
      locationTimer?.cancel();
      isWithinGeofence.value = true; // Ensure it's true for desktop
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      sendLocationUpdate();
      if (Platform.isAndroid || Platform.isIOS) {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          service.startService();
        }
      } else {
        locationTimer?.cancel();
        locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          sendLocationUpdate();
        });
      }
    }
  }

  Future<void> sendLocationUpdate() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        position = Position(
          longitude: 69.2401, latitude: 41.2995, 
          timestamp: DateTime.now(), accuracy: 0.0, 
          altitude: 0.0, altitudeAccuracy: 0.0, heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0
        );
      }

      final response = await api.updateLocation(position.latitude, position.longitude);
      if (response['status'] == 'warning') {
        isWithinGeofence.value = false;
        Get.snackbar("Eslatma", response['message'] ?? 'Hududdan tashqaridasiz.', backgroundColor: Colors.orange, colorText: Colors.white);
      } else {
        isWithinGeofence.value = true;
      }
    } catch (e) {
      print("Location update error: $e");
    }
  }

  void stopLocationTracking() {
    if (Platform.isAndroid || Platform.isIOS) {
      FlutterBackgroundService().invoke("stopService");
    }
    locationTimer?.cancel();
  }

  Future<void> checkSubscription({bool showWarning = true}) async {
    if (currentUser.value == null) return;
    try {
      final status = await api.getSubscriptionStatus();
      final bool vip = status['is_vip'] == true;
      final bool expired = status['is_expired'] == true;
      final bool active = status['is_active'] != false;
      final dynamic daysLeft = status['days_left'];
      final String? endDate = status['end_date'];

      isVip.value = vip;
      isSubscriptionExpired.value = expired || !active;
      subscriptionDaysLeft.value = vip ? null : (daysLeft as int?);
      subscriptionEndDate.value = endDate;

      if (expired || !active) {
        forceLogoutDueToExpiry(reason: !active ? 'Kafe nofaol holatda' : 'Obuna tugadi');
        return;
      }

      if (!vip && showWarning && daysLeft != null) {
        final int days = daysLeft as int;
        if (days <= 3 && days > 0) {
          Get.snackbar(
            'Obuna tugayapti!',
            'Obuna muddati $days kun ichida tugaydi. Iltimos, muddatni uzaytiring.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 8),
            snackPosition: SnackPosition.TOP,
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            margin: const EdgeInsets.all(12),
          );
        }
      }
    } catch (e) {
      print('Subscription check error: $e');
    }
  }

  void forceLogoutDueToExpiry({String reason = 'Obuna tugadi'}) {
    if (Get.isDialogOpen == true) return;
    isSubscriptionExpired.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Text(reason, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              reason == 'Obuna tugadi' 
                ? 'Kafengizning obuna muddati tugadi.\n\nTizimdan chiqib, administrator bilan bog\'laning.'
                : 'Kafengiz vaqtincha nofaol qilindi.\n\nTizimdan chiqib, administrator bilan bog\'laning.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  logout();
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Chiqish'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
    });
  }

  void setCurrentUser(Map<String, dynamic>? user) {
    currentUser.value = user;
    if (user != null) {
      storage.write('user', user);
      if (user['pin_code'] != null) {
        pinCode.value = user['pin_code'].toString();
        storage.write('pin_code', pinCode.value);
      }
      if (user['role'] != null) {
        deviceRole.value = user['role'].toString().toUpperCase();
        storage.write('device_role', deviceRole.value);
        
        // Save cafe_id for waiters so they can re-login via PIN from staff selection instead of scanning QR
        if (deviceRole.value == "WAITER" && user['cafe_id'] != null) {
          waiterCafeId.value = user['cafe_id'].toString();
          storage.write('waiter_cafe_id', waiterCafeId.value);
        }
      }
      socket.setCafeId(cafeId);
      fetchBackendData(); // Sync data immediately after login
    } else {
      storage.remove('user');
    }
  }

  void setCurrentTerminal(Map<String, dynamic>? terminal) {
    currentTerminal.value = terminal;
    if (terminal != null) {
      storage.write('terminal', terminal);
    } else {
      storage.remove('terminal');
    }
  }

  void logout({bool forced = false}) {
    stopLocationTracking();
    setCurrentUser(null);
    pinCode.value = null;
    storage.remove('pin_code');
    
    bool wasTerminal = currentTerminal.value != null;
    if (wasTerminal) {
      api.restoreTerminalToken();
    } else {
      api.setToken(null);
    }
    isPinAuthenticated.value = false;
    currentOrder.clear();

    if (deviceRole.value == null) {
      Get.offAllNamed('/role-selection');
    } else if (wasTerminal) {
      Get.offAll(() => const StaffSelectionPage());
    } else if (deviceRole.value == "WAITER" && waiterCafeId.value != null) {
      Get.offAll(() => StaffSelectionPage(cafeId: waiterCafeId.value, isFromTerminal: false));
    } else {
      Get.offAllNamed('/login');
    }
  }

  void lockTerminal() {
    authenticatePin(false);
    
    bool isTerminal = currentTerminal.value != null;
    bool isWaiterShared = deviceRole.value == "WAITER" && waiterCafeId.value != null;

    if (isTerminal || isWaiterShared) {
      // Clear current user but keep terminal/cafe context
      setCurrentUser(null);
      pinCode.value = null;
      storage.remove('pin_code');

      if (isTerminal) {
        Get.offAll(() => const StaffSelectionPage());
      } else {
        Get.offAll(() => StaffSelectionPage(cafeId: waiterCafeId.value, isFromTerminal: false));
      }
    } else {
      Get.offAll(() => const PinCodeScreen());
    }
  }

  void setPinCode(String code) {
    pinCode.value = code;
    storage.write('pin_code', code);
  }

  void authenticatePin(bool status) {
    isPinAuthenticated.value = status;
  }

  Future<bool> switchUserWithPin(String userId, String pin) async {
    try {
      final response = await api.loginWithPin(userId, pin);
      setCurrentUser(response['user']);
      authenticatePin(true);
      Get.offAllNamed('/main-navigation');
      return true;
    } catch (e) {
      Get.snackbar("Xato", "PIN kod noto'g'ri", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<String?> getStaffQRToken(String userId) async {
    try {
      final result = await api.getStaffQRToken(userId);
      return result['qr_token'];
    } catch (e) {
      print("Error getting QR token: $e");
      return null;
    }
  }

  Future<bool> loginWithQR(String qrToken) async {
    try {
      String deviceId = "mobile_${DateTime.now().millisecondsSinceEpoch}";
      final data = await api.loginWithQR(qrToken, deviceId: deviceId, deviceName: Platform.operatingSystem);
      setCurrentUser(data['user']);
      storage.write('access_token', data['access_token']);
      return true;
    } catch (e) {
      print("QR Login Error: $e");
      return false;
    }
  }
}
