import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../data/services/socket_service.dart';

Future<void> initializeService() async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return;
  }

  final service = FlutterBackgroundService();

  if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'waiter_service_channel',
        'Fassa Waiter Service',
        description: 'Bu kanal xizmatning fonda uzluksiz ishlashini ta\'minlash uchun ishlatiladi.',
        importance: Importance.low,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      const AndroidNotificationChannel callerChannel = AndroidNotificationChannel(
        'waiter_call_channel',
        'Xodim chaqiruvlari',
        description: 'Bu kanal ofitsiantlarni chaqirish uchun ishlatiladi.',
        importance: Importance.max,
        playSound: true,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(callerChannel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'waiter_service_channel',
      initialNotificationTitle: 'Fassa Waiter Service',
      initialNotificationContent: 'Xizmat ishlamoqda...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await GetStorage.init();
  final storage = GetStorage();

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
    );
  }

  // Helper to setup socket with current credentials
  bool isSocketInitialized = false;
  final audioPlayer = AudioPlayer();

  void setupSocketConnectivity() async {
    await storage.initStorage; // Refresh storage state
    final user = storage.read('user');
    if (user != null) {
      final waiterCafeId = storage.read('waiter_cafe_id');
      final String cafeId = waiterCafeId ?? user['cafe_id']?.toString() ?? "";
      
      if (cafeId.isNotEmpty) {
        final socketService = SocketService();
        socketService.setCafeId(cafeId);
        socketService.socket.connect();
        
        socketService.onWaiterCall((data) async {
          if (user['id']?.toString() == data['waiter_id']?.toString()) {
            try {
              await audioPlayer.stop();
              await audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
            } catch (e) {
              print("Background sound playback error: $e");
            }
            
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 2000, amplitude: 255);
            }
            
            if (Platform.isAndroid) {
              const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
                'waiter_call_channel',
                'Xodim chaqiruvlari',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,
                category: AndroidNotificationCategory.status,
                visibility: NotificationVisibility.public,
                playSound: true,
                ongoing: false,
                autoCancel: true,
                styleInformation: BigTextStyleInformation(''),
              );
              const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidDetails);
              flutterLocalNotificationsPlugin.show(
                DateTime.now().millisecond,
                'Chaqiruv!',
                '${data['sender_name']} sizni chaqirmoqda',
                platformChannelSpecifics,
              );
            }
          }
        });
        isSocketInitialized = true;
      }
    }
  }

  // Initial setup
  setupSocketConnectivity();

  // Also listen for manual refresh from main app
  service.on('refreshConfig').listen((event) {
    setupSocketConnectivity();
  });

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (!isSocketInitialized) {
      setupSocketConnectivity();
    }
    
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }
    }

    final String? token = storage.read('access_token');
    if (token == null) return;

    // Check working hours
    final String start = storage.read('work_start_time') ?? "00:00";
    final String end = storage.read('work_end_time') ?? "23:59";
    
    bool isWorkTime() {
      final now = DateTime.now();
      final nowMinutes = now.hour * 60 + now.minute;
      
      final startParts = start.split(':');
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      
      final endParts = end.split(':');
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      
      if (startMinutes <= endMinutes) {
        return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
      } else {
        // Overnight: e.g. 22:00 to 04:00
        return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
      }
    }

    if (!isWorkTime()) {
      print("Outside working hours ($start - $end), skipping location update.");
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final String baseUrl = storage.read('api_url') ?? 'https://cafe-backend-code-production.up.railway.app';

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Authorization': 'Bearer $token'},
      ));

      await dio.post('/auth/location', data: {
        'lat': position.latitude,
        'lng': position.longitude,
      });

      print("Background location update success: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Background location update error: $e");
    }
  });
}
