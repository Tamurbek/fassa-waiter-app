import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import '../../../theme/app_colors.dart';
import '../main_navigation_screen.dart';
import 'pin_code_screen.dart';
import 'terminal_selection_page.dart';

import 'staff_selection_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      Get.snackbar(
        'Error',
        'Please fill in all fields',
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);
    
    String deviceId = "unknown_device";
    String deviceName = "Unknown Device";
    
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        deviceId = webInfo.userAgent ?? "web_browser";
        deviceName = webInfo.browserName.name;
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = "${androidInfo.brand} ${androidInfo.model}";
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "ios_device";
        deviceName = iosInfo.name;
      }
    } catch (e) {
      print("Error getting device info: $e");
    }

    final inputText = _emailController.text.trim();
    final passwordText = _passwordController.text;

    try {
      // 1. TERMINAL LOGIN (if input is not an email)
      if (!inputText.contains('@')) {
        final response = await ApiService().loginTerminal(inputText, passwordText);
        Get.find<POSController>().setCurrentTerminal(response['terminal']);
        
        Get.snackbar(
          'Muvaffaqiyatli',
          '${response['terminal']['name']} terminaliga ulandi',
          backgroundColor: Colors.green.withOpacity(0.7),
          colorText: Colors.white,
        );
        Get.offAll(() => const StaffSelectionPage());
        return;
      }

      // 2. USER LOGIN (if input is an email)
      final response = await ApiService().login(
        inputText,
        passwordText,
        deviceId: deviceId,
        deviceName: deviceName,
      );

      // Save user to controller
      Get.find<POSController>().setCurrentUser(response['user']);
      
      try {
        final subStatus = await ApiService().getSubscriptionStatus();
        final bool isExpired = subStatus['is_expired'] == true;
        final bool isActive = subStatus['is_active'] != false;

        if (isExpired || !isActive) {
          Get.snackbar(
            isExpired ? 'Obuna muddati tugagan' : 'Kafe nofaol',
            isExpired 
              ? 'Sizning obuna muddatingiz tugagan. Iltimos, administrator bilan bog\'laning.'
              : 'Kafengiz vaqtincha nofaol qilindi. Iltimos, administrator bilan bog\'laning.',
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.all(12),
            snackPosition: SnackPosition.TOP,
          );
          Get.find<POSController>().logout();
          return;
        }
      } catch (e) {
        print("Subscription check error on login: $e");
      }

      Get.snackbar(
        'Success',
        'Welcome back, ${response['user']['name']}!',
        backgroundColor: Colors.green.withOpacity(0.7),
        colorText: Colors.white,
      );

      // Redirect based on role and PIN setup
      final pos = Get.find<POSController>();
      final String role = response['user']['role'];
      
      if (role == 'SYSTEM_ADMIN' || role == 'CAFE_ADMIN') {
        Get.offAll(() => const TerminalSelectionPage());
      } else if (pos.pinCode.value == null) {
        Get.offAll(() => const PinCodeScreen(isSettingNewPin: true));
      } else {
        Get.offAll(() => const PinCodeScreen());
      }
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        inputText.contains('@') ? 'Invalid email or password' : 'Invalid terminal username or password',
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (isDesktop)
            Expanded(
              flex: 1,
              child: Stack(
                children: [
                  Container(
                    color: const Color(0xFFFF9500),
                    child: CustomPaint(
                      painter: GridPainter(),
                      size: Size.infinite,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildMockupLogo(),
                        const SizedBox(height: 48),
                        const Text(
                          'Fast Food Pro',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The most powerful POS for your\nbusiness',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTag('Reliable'),
                            const SizedBox(width: 12),
                            _buildTag('Fast'),
                            const SizedBox(width: 12),
                            _buildTag('Modern'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? size.width * 0.08 : 24,
                vertical: 40,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isDesktop) ...[
                    Center(child: _buildMobileLogo()),
                    const SizedBox(height: 40),
                  ],
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'login_subtitle'.tr,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildLabel('login_id_or_email'.tr),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'login_id_or_email'.tr,
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('password'.tr),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'forgot_password'.tr,
                          style: const TextStyle(
                            color: Color(0xFFFF9500),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'password'.tr,
                    prefixIcon: Icons.lock_outline_rounded,
                    isPassword: true,
                    obscureText: _obscurePassword,
                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: false,
                          onChanged: (v) {},
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'remember_me'.tr,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9500),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'sign_in'.tr,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        children: [
                          TextSpan(text: "${'dont_have_account'.tr} "),
                          TextSpan(
                            text: 'contact_support'.tr,
                            style: const TextStyle(
                              color: Color(0xFFFF9500),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'V4.2.0 STABLE',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        '© 2024 FAST FOOD PRO',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockupLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED).withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.fastfood, color: Color(0xFFFF9500), size: 60),
        ),
      ),
    );
  }

  Widget _buildMobileLogo() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(Icons.fastfood, color: Color(0xFFFF9500), size: 36),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4B5563),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && obscureText,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w500),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF9CA3AF), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
