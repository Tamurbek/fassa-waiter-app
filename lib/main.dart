import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'logic/pos_controller.dart';
import 'theme/app_theme.dart';
import 'presentation/pages/main_navigation_screen.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/pin_code_screen.dart';
import 'translations/app_translations.dart';
import 'presentation/pages/settings_screen.dart';
import 'presentation/pages/auth/staff_selection_page.dart';
import 'presentation/pages/auth/terminal_login_page.dart';
import 'presentation/pages/auth/qr_scanner_page.dart';
import 'presentation/pages/auth/welcome_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'logic/background_service.dart';
import 'presentation/components/location_checker.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'dart:async';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize essential components with error handling
  try {
    // 1. Storage with timeout to prevent hanging
    await GetStorage.init().timeout(const Duration(seconds: 3), onTimeout: () {
      print("Storage initialization timed out, continuing anyway...");
      return false;
    });
    
    // 2. Localization
    unawaited(initializeDateFormatting('uz_UZ', null));
    unawaited(initializeDateFormatting('en_US', null));
    unawaited(initializeDateFormatting('ru_RU', null));
    
    // 3. Background Service
    initializeService().catchError((e) {
      print("Background service error: $e");
    });
    
    // 4. Controller
    Get.put(POSController());
    
  } catch (e) {
    print("Startup error: $e");
  }

  runApp(const FassaApp());
  
  // Ensure splash screen is removed even if build takes time
  Future.delayed(const Duration(milliseconds: 500), () {
    FlutterNativeSplash.remove();
  });
}

class FassaApp extends StatelessWidget {
  const FassaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = Get.find<POSController>();
    final storage = GetStorage();
    
    pos.restaurantName.value = storage.read('restaurant_name') ?? "Fassa";
    String? storedLang = storage.read('lang');
    Locale initialLocale = const Locale('uz', 'UZ');
    
    if (storedLang != null) {
      try {
        final parts = storedLang.split('_');
        if (parts.length >= 2) {
          initialLocale = Locale(parts[0], parts[1]);
        } else if (parts.length == 1) {
          initialLocale = Locale(parts[0]);
        }
      } catch (e) {
        print("Locale parse error: $e");
      }
    }

    return GetMaterialApp(
      title: 'Fassa Waiter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: pos.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
      translations: AppTranslations(),
      locale: initialLocale,
      fallbackLocale: const Locale('en', 'US'),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return LocationChecker(child: child);
      },
      home: _getInitialScreen(),
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/pin', page: () => const PinCodeScreen()),
        GetPage(name: '/main', page: () => const MainNavigationScreen()),
        GetPage(name: '/settings', page: () => const SettingsScreen()),
        GetPage(name: '/staff-selection', page: () => const StaffSelectionPage()),
        GetPage(name: '/terminal-login', page: () => const TerminalLoginPage()),
        GetPage(name: '/welcome', page: () => const WelcomePage()),
      ],
    );
  }

  Widget _getInitialScreen() {
    final pos = Get.find<POSController>();
    
    // 0. Force WAITER role for this app
    if (pos.deviceRole.value != "WAITER") {
      pos.setDeviceRole("WAITER");
    }
    
    // 1. Check if Waiter is logged in
    if (pos.currentUser.value == null) {
      if (pos.waiterCafeId.value != null) {
        return StaffSelectionPage(cafeId: pos.waiterCafeId.value, isFromTerminal: false);
      } else {
        // Initial setup for waiter: show welcome page first
        return const WelcomePage();
      }
    }
    
    // 2. Staff is logged in, check personal PIN
    if (!pos.isPinAuthenticated.value) {
      if (pos.pinCode.value == null) {
        return const PinCodeScreen(isSettingNewPin: true);
      } else {
        return const PinCodeScreen();
      }
    }
    
    // 3. Authenticated - Go to Main Screen
    return const MainNavigationScreen();
  }
}
