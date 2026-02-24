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
        'location_service_channel',
        'Location Service',
        description: 'This channel is used for location tracking.',
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
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'location_service_channel',
      initialNotificationTitle: 'Location Tracking',
      initialNotificationContent: 'Track xodimlari joylashuvi faol',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
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

  final user = storage.read('user');
  if (user != null) {
    final waiterCafeId = storage.read('waiter_cafe_id');
    final String cafeId = waiterCafeId ?? user['cafe_id']?.toString() ?? "";
    
    if (cafeId.isNotEmpty) {
      final socketService = SocketService();
      socketService.setCafeId(cafeId);
      final audioPlayer = AudioPlayer();
      
      socketService.onWaiterCall((data) async {
        if (user['id']?.toString() == data['waiter_id']?.toString()) {
          try {
            await audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
          } catch (e) {
            print("Background sound playback error: $e");
          }
          
          if (await Vibration.hasVibrator()) {
            Vibration.vibrate(duration: 2000, amplitude: 255);
          }
          
          if (Platform.isAndroid) {
            const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
              'waiter_call_channel',
              'Xodim chaqiruvlari',
              importance: Importance.max,
              priority: Priority.high,
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
    }
  }

  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (!(await service.isForegroundService())) {
        return;
      }
    }

    final String? token = storage.read('access_token');
    if (token == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final dio = Dio(BaseOptions(
        baseUrl: 'https://cafe-backend-code-production.up.railway.app',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
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
