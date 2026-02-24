import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../logic/pos_controller.dart';

class LocationChecker extends StatefulWidget {
  final Widget child;
  const LocationChecker({Key? key, required this.child}) : super(key: key);

  @override
  State<LocationChecker> createState() => _LocationCheckerState();
}

class _LocationCheckerState extends State<LocationChecker> with WidgetsBindingObserver {
  bool _isServiceEnabled = true;
  LocationPermission _permission = LocationPermission.always;
  StreamSubscription<ServiceStatus>? _serviceStatusStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocation();
    
    // Listen to location service status changes
    _serviceStatusStreamSubscription = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (mounted) {
        setState(() {
          _isServiceEnabled = status == ServiceStatus.enabled;
        });
        if (status == ServiceStatus.enabled) {
          _checkLocation();
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLocation();
    }
  }

  Future<void> _checkLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (mounted) {
      setState(() {
        _isServiceEnabled = serviceEnabled;
        _permission = permission;
      });
    }

    if (serviceEnabled && (permission == LocationPermission.denied || permission == LocationPermission.deniedForever)) {
      permission = await Geolocator.requestPermission();
      if (mounted) {
        setState(() {
          _permission = permission;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = Get.find<POSController>();
    
    // Only enforce location check for Waiters
    bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (pos.deviceRole.value != "WAITER" || isDesktop) {
      return widget.child;
    }

    bool hasIssue = !_isServiceEnabled || _permission == LocationPermission.denied || _permission == LocationPermission.deniedForever;

    if (!hasIssue) {
      return widget.child;
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Joylashuv xizmati majburiy',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  !_isServiceEnabled 
                      ? 'Ilovadan foydalanish uchun qurilmangizning GPS (Joylashuv) xizmatini yoqishingiz kerak.'
                      : 'Ilovadan foydalanish uchun joylashuvni aniqlashga ruxsat berishingiz kerak.',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    if (!_isServiceEnabled) {
                      await Geolocator.openLocationSettings();
                    } else {
                      LocationPermission p = await Geolocator.requestPermission();
                      if (p == LocationPermission.deniedForever) {
                        await Geolocator.openAppSettings();
                      } else {
                        _checkLocation();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(!_isServiceEnabled ? 'Sozlamalarni ochish' : 'Ruxsat berish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
