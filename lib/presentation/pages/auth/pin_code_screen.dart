import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/responsive.dart';
import '../main_navigation_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'dart:io';
import 'package:vibration/vibration.dart';

class PinCodeScreen extends StatefulWidget {
  final bool isSettingNewPin;
  final dynamic selectedUser;
  final bool isFromTerminal;

  const PinCodeScreen({
    super.key, 
    this.isSettingNewPin = false,
    this.selectedUser,
    this.isFromTerminal = false,
  });

  @override
  State<PinCodeScreen> createState() => _PinCodeScreenState();
}

class _PinCodeScreenState extends State<PinCodeScreen> {
  final POSController pos = Get.find<POSController>();
  String _enteredPin = "";
  String _firstPin = ""; 
  bool _isConfirming = false;
  late bool isSettingNewPin;
  final LocalAuthentication auth = LocalAuthentication();
  bool _canCheckBiometrics = false;
  bool _isNfcAvailable = false;

  @override
  void initState() {
    super.initState();
    isSettingNewPin = widget.isSettingNewPin;
    if (Get.arguments != null && Get.arguments is Map) {
      if (Get.arguments['isSettingNewPin'] != null) {
        isSettingNewPin = Get.arguments['isSettingNewPin'];
      }
    }
    _checkBiometrics();
    _initNfc();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    try {
      bool canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      setState(() {
        _canCheckBiometrics = canCheck;
      });
      
      // Auto-trigger biometrics if allowed and not setting new PIN
      if (canCheck && !isSettingNewPin && !widget.isFromTerminal) {
        _authenticateBiometrically();
      }
    } catch (e) {
      print("Check biometrics error: $e");
    }
  }

  Future<void> _initNfc() async {
    try {
      _isNfcAvailable = await NfcManager.instance.isAvailable();
      if (_isNfcAvailable) {
        _startNfcSession();
      }
    } catch (e) {
      print("NFC Error: $e");
    }
  }

  void _startNfcSession() {
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      try {
        final ndef = Ndef.from(tag);
        // We can get identifier (ID) from tag.data
        String? nfcId;
        
        // Extract ID from tag data
        if (tag.data.containsKey('nfca')) {
          nfcId = (tag.data['nfca']['identifier'] as List).map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
        } else if (tag.data.containsKey('mifareclassic')) {
          nfcId = (tag.data['mifareclassic']['identifier'] as List).map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
        }
        
        if (nfcId != null) {
          debugPrint("NFC Tag Discovered: $nfcId");
          _handleNfcLogin(nfcId);
        }
      } catch (e) {
        debugPrint("NFC Read Error: $e");
      }
    });
  }

  Future<void> _handleNfcLogin(String nfcId) async {
    // Professional feedback: Vibrate and show overlay
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100);
    }

    Get.showOverlay(
      asyncFunction: () async {
        try {
          final response = await ApiService().loginWithNfc(
            nfcId,
            deviceName: "${Platform.operatingSystem} ${Platform.isAndroid ? 'Android' : 'iOS'}",
          );
          
          if (response['user'] != null) {
            pos.setCurrentUser(response['user']);
            pos.authenticatePin(true);
            
            // Show success animation/feedback
            Get.snackbar(
              "Muvaffaqiyatli", 
              "Karta orqali kirildi: ${response['user']['name']}", 
              backgroundColor: Colors.green, 
              colorText: Colors.white,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              snackPosition: SnackPosition.TOP,
            );
            
            Get.offAll(() => const MainNavigationScreen());
          }
        } catch (e) {
          debugPrint("NFC Login Error: $e");
          Get.snackbar(
            "Xato", 
            "Ushbu NFC karta tizimga biriktirilmagan", 
            backgroundColor: Colors.red, 
            colorText: Colors.white,
            icon: const Icon(Icons.error_outline, color: Colors.white),
          );
        }
      },
      opacity: 0.1,
      loadingWidget: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Karta tekshirilmoqda...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _authenticateBiometrically() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Tizimga kirish uchun biometrik ma\'lumotni tasdiqlang',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        // If authenticated, we use the stored PIN to log in
        if (pos.pinCode.value != null) {
          setState(() {
            _enteredPin = pos.pinCode.value!;
          });
          _handlePinComplete();
        } else {
          Get.snackbar("Eslatma", "PIN kod sozlanmagan. Iltimos, birinchi marta PIN kiriting.", 
            backgroundColor: Colors.orange, colorText: Colors.white);
        }
      }
    } catch (e) {
      print("Auth error: $e");
    }
  }

  void _onDigitPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _handlePinComplete() async {
    if (widget.isFromTerminal && widget.selectedUser != null) {
      try {
        final userId = widget.selectedUser['id'].toString();
        final response = await ApiService().loginWithPin(userId, _enteredPin);
        
        // Save user to controller
        Get.find<POSController>().setCurrentUser(response['user']);
        pos.authenticatePin(true);
        
        Get.snackbar("Muvaffaqiyatli", "Xush kelibsiz, ${response['user']['name']}!", 
          backgroundColor: Colors.green, colorText: Colors.white);
          
        Get.offAll(() => const MainNavigationScreen());
      } catch (e) {
        Get.snackbar("Xato", "PIN kod noto'g'ri", 
          backgroundColor: Colors.red, colorText: Colors.white);
        setState(() {
          _enteredPin = "";
        });
      }
      return;
    }

    if (isSettingNewPin) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = "";
          _isConfirming = true;
        });
      } else {
        if (_enteredPin == _firstPin) {
          pos.setPinCode(_enteredPin);
          pos.authenticatePin(true);
          Get.snackbar("Success", "PIN code established successfully", 
            backgroundColor: Colors.green, colorText: Colors.white);
          Get.offAll(() => const MainNavigationScreen());
        } else {
          Get.snackbar("Error", "PIN codes do not match. Try again.", 
            backgroundColor: Colors.red, colorText: Colors.white);
          setState(() {
            _enteredPin = "";
          });
        }
      }
    } else {
      if (_enteredPin == pos.pinCode.value) {
        pos.authenticatePin(true);
        Get.offAll(() => const MainNavigationScreen());
      } else {
        Get.snackbar("Error", "Incorrect PIN code", 
          backgroundColor: Colors.red, colorText: Colors.white);
        setState(() {
          _enteredPin = "";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String titleText = isSettingNewPin 
      ? (_isConfirming ? "confirm_pin".tr : "set_new_pin".tr) 
      : "enter_pin".tr;
    
    if (widget.isFromTerminal && widget.selectedUser != null) {
      titleText = widget.selectedUser['name'];
    } else if (!isSettingNewPin && pos.currentUser.value != null) {
      titleText = pos.currentUser.value?['name'] ?? "enter_pin".tr;
    }

    String subtitleText = isSettingNewPin
      ? (_isConfirming ? "confirm_pin_msg".tr : "set_pin_msg".tr)
      : "pin_subtitle".tr;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 400,
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              children: [
                                _buildHeaderIcon(),
                                if (_isNfcAvailable && !isSettingNewPin) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.nfc, size: 14, color: Colors.blue),
                                        SizedBox(width: 6),
                                        Text(
                                          "NFC karta tayyor",
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A1A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildPinIndicators(),
                            const SizedBox(height: 32),
                            _buildKeypad(),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () {},
                              child: Text(
                                'forgot_pin'.tr,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => pos.logout(),
                              icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                              label: const Text(
                                'Tizimdan chiqish',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (widget.isFromTerminal) ...[
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: _showQrDialog,
                                icon: const Icon(Icons.qr_code_2, color: Color(0xFFFF9500), size: 18),
                                label: const Text(
                                  'Sozlash uchun QR kod',
                                  style: TextStyle(
                                    color: Color(0xFFFF9500),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Center(child: Text('Tizim sozlamalari')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Xodimlar ushbu QR kodni skanerlash orqali tizimga avtomatik ulanishlari mumkin',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: "${ApiService().currentBaseUrl}|${pos.currentTerminal.value?['cafe_id'] ?? ''}",
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ApiService().currentBaseUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Yopish'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFFFFF7ED),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.lock_rounded,
          color: Color(0xFFFF9500),
          size: 36,
        ),
      ),
    );
  }

  Widget _buildPinIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final bool isFilled = index < _enteredPin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? const Color(0xFFFF9500) : Colors.white,
            border: Border.all(
              color: isFilled ? const Color(0xFFFF9500) : const Color(0xFFD1D5DB),
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1'),
            const SizedBox(width: 12),
            _buildKeypadButton('2'),
            const SizedBox(width: 12),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4'),
            const SizedBox(width: 12),
            _buildKeypadButton('5'),
            const SizedBox(width: 12),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7'),
            const SizedBox(width: 12),
            _buildKeypadButton('8'),
            const SizedBox(width: 12),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_canCheckBiometrics && !isSettingNewPin)
              _buildKeypadButton('', isBiometric: true)
            else
              const SizedBox(width: 72),
            const SizedBox(width: 12),
            _buildKeypadButton('0'),
            const SizedBox(width: 12),
            _buildKeypadButton('', isBackspace: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit, {bool isBackspace = false, bool isBiometric = false}) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          if (isBackspace) {
            _onBackspace();
          } else if (isBiometric) {
            _authenticateBiometrically();
          } else {
            _onDigitPress(digit);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: isBackspace
                ? const Icon(Icons.backspace_outlined, color: Color(0xFF4B5563), size: 22)
                : (isBiometric 
                   ? const Icon(Icons.fingerprint_rounded, color: Color(0xFFFF9500), size: 32)
                   : Text(
                    digit,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  )),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF9CA3AF), size: 14),
              const SizedBox(width: 8),
              Text(
                'secure_encryption'.tr,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '© 2024 POS System Cloud. ${'all_rights_reserved'.tr}',
            style: const TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
