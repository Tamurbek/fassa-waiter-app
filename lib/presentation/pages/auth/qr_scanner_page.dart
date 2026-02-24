import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get/get.dart';
import '../../../data/services/api_service.dart';
import '../../../logic/pos_controller.dart';
import 'staff_selection_page.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR kodni skanerlang'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_isScanned) return;
              
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                   _isScanned = true;
                   _handleScannedData(code);
                   break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Terminaldagi QR kodni kvadratchaga to\'g\'rilang',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScannedData(String data) async {
    String? token;
    String? overrideUrl;

    if (data.contains('|')) {
      final parts = data.split('|');
      if (parts.length >= 2) {
        overrideUrl = parts[0];
        final secondPart = parts[1];
        if (secondPart.contains('.')) {
          token = secondPart;
        }
      }
    } else if (data.contains('.')) {
      token = data;
    }

    // 1. If it's a QR Login Token
    if (token != null) {
       Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
       
       if (overrideUrl != null && overrideUrl.startsWith('http')) {
         ApiService().setBaseUrl(overrideUrl);
       }

       final success = await Get.find<POSController>().loginWithQR(token);
       Get.back(); // Close loading

       if (success) {
         Get.snackbar('Muvaffaqiyatli', 'Tizimga kirdingiz', backgroundColor: Colors.green, colorText: Colors.white);
         final pos = Get.find<POSController>();
         if (pos.pinCode.value == null) {
           Get.offAllNamed('/pin', arguments: {'isSettingNewPin': true});
         } else {
           Get.offAllNamed('/main');
         }
       } else {
         Get.snackbar('Xato', 'QR kod yaroqsiz yoki muddati o\'tgan', backgroundColor: Colors.red, colorText: Colors.white);
         _isScanned = false;
       }
       return;
    }

    // 2. Terminal connection logic (Original)
    String url = data;
    String? cafeId;
    
    if (data.contains('|')) {
      final parts = data.split('|');
      url = parts[0];
      cafeId = parts[1];
    }

    if (!url.startsWith('http')) {
      Get.snackbar('Xato', 'Noto\'g\'ri QR kod formati', backgroundColor: Colors.red, colorText: Colors.white);
      _isScanned = false;
      return;
    }

    ApiService().setBaseUrl(url);
    
    Get.snackbar(
      'Muvaffaqiyatli',
      'Tizimga ulanish o\'rnatildi',
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );

    if (cafeId != null && cafeId.isNotEmpty) {
      Get.find<POSController>().setWaiterCafeId(cafeId);
      Get.off(() => StaffSelectionPage(cafeId: cafeId, isFromTerminal: false));
    } else {
      Get.back();
    }
  }
}
