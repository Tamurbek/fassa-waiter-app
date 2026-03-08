import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/printer_model.dart';
import '../../logic/pos_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();
  
  CapabilityProfile? _cachedProfile;
  Future<CapabilityProfile> _getProfile() async {
    _cachedProfile ??= await CapabilityProfile.load();
    return _cachedProfile!;
  }

  String _formatPrice(dynamic amount) {
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat("#,###", "en_US");
    return formatter.format(value).replaceAll(',', ' ');
  }

  String _normalizeString(String? text) {
    if (text == null) return "";
    // Comprehensive Cyrillic to Latin transliteration for printers without Cyrillic support
    Map<String, String> replacements = {
      'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo', 'Ж': 'Zh', 
      'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O', 
      'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 
      'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Sch', 'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', 'ж': 'zh', 
      'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 
      'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts', 
      'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      'Ў': 'O\'', 'ў': 'o\'', 'Қ': 'Q', 'қ': 'q', 'Ғ': 'G\'', 'ғ': 'g\'', 'Ҳ': 'H', 'ҳ': 'h',
    };
    String result = text;
    replacements.forEach((key, value) => result = result.replaceAll(key, value));
    return result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  Future<bool> printReceipt(PrinterModel printer, Map<String, dynamic> order, {String? title, bool isKitchenOnly = false}) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await _getProfile();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];
      final posController = Get.find<POSController>();

      // Using hardcoded professional layout for now
      final layout = []; 

      if (layout.isEmpty) {
        // Fallback for empty layout
        bytes += generator.text(_normalizeString(posController.restaurantName.value), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
        bytes += generator.hr();
        bytes += generator.text(_normalizeString('ID: ${order['id']}'), styles: const PosStyles(align: PosAlign.center));
        bytes += generator.text(_normalizeString(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())), styles: const PosStyles(align: PosAlign.center));
        
        final String waiterName = order['waiter_name'] ?? posController.currentUser.value?['name'] ?? "";
        if (waiterName.isNotEmpty) {
           bytes += generator.text(_normalizeString('AFITSANT: $waiterName'), styles: const PosStyles(align: PosAlign.left));
        }
        bytes += generator.feed(1);
        final items = order['details'] as List;
        for (var item in items) {
          final qty = (item['qty'] as num).toInt();
          final price = (item['price'] as num).toDouble();
          double lineTotal = qty * price;
          
          bytes += generator.text(_normalizeString(item['name']), styles: PosStyles(bold: true, height: isKitchenOnly ? PosTextSize.size3 : PosTextSize.size1));
          
          if (isKitchenOnly) {
             bytes += generator.text(_normalizeString('SONI: $qty ta'), styles: const PosStyles(bold: true, height: PosTextSize.size3, width: PosTextSize.size2));
             bytes += generator.feed(1);
          } else {
            bytes += generator.row([
              PosColumn(text: _normalizeString('  $qty x ${_formatPrice(price)}'), width: 7, styles: const PosStyles(fontType: PosFontType.fontB)),
              PosColumn(text: _normalizeString(_formatPrice(lineTotal)), width: 5, styles: const PosStyles(align: PosAlign.right)),
            ]);
          }
        }
        bytes += generator.hr();
        if (!isKitchenOnly) {
           final String payMethod = (order['payment_method'] ?? "").toString().toUpperCase();
           if (payMethod.isNotEmpty) {
              bytes += generator.text(_normalizeString('TO\'LOV TURI: $payMethod'), styles: const PosStyles(align: PosAlign.center, bold: true));
           }
           bytes += generator.hr();
           bytes += _row(generator, 'JAMI:', _formatPrice(order['total']), styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
        }
      } else {
        for (int i = 0; i < layout.length; i++) {
          var element = layout[i];
          if (!(element['enabled'] ?? true)) continue;

          final width = element['width'] ?? 100;
          if (width == 50 && i + 1 < layout.length) {
            int nextIdx = -1;
            for (int j = i + 1; j < layout.length; j++) {
              if (layout[j]['enabled'] ?? true) { nextIdx = j; break; }
            }
            if (nextIdx != -1 && layout[nextIdx]['width'] == 50) {
              bytes += _printSideBySide(generator, element, layout[nextIdx], posController);
              i = nextIdx;
              continue;
            }
          }
          bytes += await _printElement(generator, element, order, posController, printer, title, isKitchenOnly);
        }
      }

      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(printer.ipAddress, printer.port, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print('Manual layout print failed: $e');
      return false;
    }
  }

  PosStyles _getStyles(Map<String, dynamic> element, {bool defaultBold = false, PosAlign defaultAlign = PosAlign.center, PosTextSize defaultSize = PosTextSize.size1}) {
    final props = element['props'] ?? {};
    
    PosAlign align = defaultAlign;
    if (props['align'] == 'LEFT') align = PosAlign.left;
    else if (props['align'] == 'CENTER') align = PosAlign.center;
    else if (props['align'] == 'RIGHT') align = PosAlign.right;

    bool bold = props['bold'] ?? defaultBold;
    
    PosTextSize size = defaultSize;
    if (props['size'] == 'LARGE') size = PosTextSize.size2;
    else if (props['size'] == 'XLARGE') size = PosTextSize.size3;
    else if (props['size'] == 'NORMAL') size = PosTextSize.size1;

    PosFontType font = PosFontType.fontA;
    if (props['font'] == 'B') font = PosFontType.fontB;

    return PosStyles(
      align: align,
      bold: bold,
      height: size,
      width: size,
      fontType: font,
    );
  }

  Future<List<int>> _printElement(Generator generator, Map<String, dynamic> element, Map<String, dynamic> order, POSController posController, PrinterModel printer, String? title, bool isKitchenOnly) async {
    List<int> bytes = [];
    final type = element['type'];
    final styles = _getStyles(element);

    switch (type) {
      case 'HEADER':
      case 'STORE_NAME':
        bytes += generator.text(_normalizeString(posController.restaurantName.value), styles: _getStyles(element, defaultBold: true, defaultSize: PosTextSize.size2));
        if (posController.restaurantAddress.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantAddress.value), styles: _getStyles(element));
        if (posController.restaurantPhone.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantPhone.value), styles: _getStyles(element));
        break;
      case 'LOGO':
      case 'CAFE_LOGO':
        if (posController.showLogo.value && posController.restaurantLogo.value.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(posController.restaurantLogo.value)).timeout(const Duration(seconds: 5));
            final image = img.decodeImage(response.bodyBytes);
            if (image != null) {
              final maxWidth = printer.paperSize == '58mm' ? 150 : 200;
              img.Image resized = img.copyResize(image, width: maxWidth);
              bytes += generator.image(resized, align: styles.align);
            }
          } catch (e) {}
        }
        break;
      case 'STORE_ADDRESS':
        if (posController.restaurantAddress.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantAddress.value), styles: styles);
        break;
      case 'STORE_PHONE':
        if (posController.restaurantPhone.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantPhone.value), styles: styles);
        break;
      case 'ORDER_INFO':
        if (title != null) bytes += generator.text(_normalizeString(title.toUpperCase()), styles: _getStyles(element, defaultBold: true));
        bytes += generator.text(_normalizeString('ID: ${order['id']}'), styles: styles);
        bytes += generator.text(_normalizeString(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())), styles: styles);
        
        final String waiterName = order['waiter_name'] ?? posController.currentUser.value?['name'] ?? "";
        if (waiterName.isNotEmpty) {
           bytes += generator.text(_normalizeString('AFITSANT: $waiterName'), styles: styles);
        }

        if (order['table'] != null && order['table'] != '-') {
            bytes += generator.text(_normalizeString('STOL: ${order['table']}'), styles: _getStyles(element, defaultBold: true, defaultSize: isKitchenOnly ? PosTextSize.size3 : PosTextSize.size2));
        }
        break;
      case 'ITEMS_TABLE':
        bytes += generator.hr(ch: '-');
        final items = order['details'] as List;
        for (var item in items) {
          final qty = (item['qty'] as num).toInt();
          final price = (item['price'] as num).toDouble();
          double lineTotal = qty * price;
          
          // Name Line (Bold)
          bytes += generator.text(_normalizeString(item['name']), styles: styles.copyWith(bold: true, height: isKitchenOnly ? PosTextSize.size3 : PosTextSize.size1));
          
          if (isKitchenOnly) {
             bytes += generator.text(_normalizeString('SONI: $qty ta'), styles: styles.copyWith(bold: true, height: PosTextSize.size3, width: PosTextSize.size2));
             bytes += generator.feed(1);
          } else {
            // Stats Line
            bytes += generator.row([
              PosColumn(text: _normalizeString('  $qty x ${_formatPrice(price)}'), width: 7, styles: styles.copyWith(fontType: PosFontType.fontB)),
              PosColumn(text: _normalizeString(_formatPrice(lineTotal)), width: 5, styles: styles.copyWith(align: PosAlign.right)),
            ]);
          }
        }
        bytes += generator.hr(ch: '-');
        break;
      case 'TOTAL_BLOCK':
        if (isKitchenOnly) break;
        double subtotal = 0;
        final items = (order['details'] as List);
        for (var item in items) {
          subtotal += (double.tryParse(item['price'].toString()) ?? 0.0) * (int.tryParse(item['qty'].toString()) ?? 0);
        }
        
        bytes += _row(generator, 'SUMMA:', _formatPrice(subtotal), styles: styles);
        
        // Calculate Service Fee
        double feePercent = 0.0;
        double feeFixed = 0.0;
        final String mode = (order['mode'] ?? "Dine-in").toString().toLowerCase();
        
        if (mode.contains("dine")) {
          feePercent = (order['service_fee_dine_in'] as num?)?.toDouble() ?? 10.0;
        } else if (mode.contains("takeaway")) {
          feeFixed = (order['service_fee_takeaway'] as num?)?.toDouble() ?? 0.0;
        } else if (mode.contains("delivery")) {
          feeFixed = (order['service_fee_delivery'] as num?)?.toDouble() ?? 0.0;
        }

        double feeAmt = feeFixed;
        if (feePercent > 0) {
          feeAmt = subtotal * (feePercent / 100);
          bytes += _row(generator, 'XIZMAT (${feePercent.toInt()}%):', _formatPrice(feeAmt), styles: styles);
        } else if (feeFixed > 0) {
          bytes += _row(generator, 'XIZMAT:', _formatPrice(feeAmt), styles: styles);
        }

        final double discountAmt = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
        if (discountAmt > 0) {
          bytes += _row(generator, 'CHEGIRMA:', '-${_formatPrice(discountAmt)}', styles: styles.copyWith(bold: true));
        }
        
        double finalTotal = subtotal + feeAmt - discountAmt;
        if (finalTotal < 0) finalTotal = 0;

        bytes += generator.hr(ch: '=');
        bytes += generator.row([
          PosColumn(text: _normalizeString('JAMI:'), width: 5, styles: styles.copyWith(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
          PosColumn(text: _normalizeString('${_formatPrice(finalTotal)}'), width: 7, styles: styles.copyWith(bold: true, align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2)),
        ]);
        bytes += generator.hr(ch: '=');
        break;
      case 'DIVIDER':
        bytes += generator.hr(ch: '-');
        break;
      case 'SPACER':
        bytes += generator.feed(1);
        break;
      case 'INSTAGRAM_QR':
        String link = posController.instagramLink.value;
        if (link.isEmpty && posController.instagram.value.isNotEmpty) link = "https://instagram.com/${posController.instagram.value.replaceAll('@', '')}";
        if (link.isNotEmpty) {
           bytes += generator.text(_normalizeString('INSTAGRAM'), styles: styles.copyWith(bold: true));
           bytes += generator.qrcode(link, size: _getQRSize(element['props']?['size']), align: styles.align);
        }
        break;
      case 'TELEGRAM_QR':
        String link = posController.telegramLink.value;
        if (link.isEmpty && posController.telegram.value.isNotEmpty) link = "https://t.me/${posController.telegram.value.replaceAll('t.me/', '')}";
        if (link.isNotEmpty) {
           bytes += generator.text(_normalizeString('TELEGRAM'), styles: styles.copyWith(bold: true));
           bytes += generator.qrcode(link, size: _getQRSize(element['props']?['size']), align: styles.align);
        }
        break;
      case 'FOOTER':
        if (posController.receiptFooter.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.receiptFooter.value), styles: styles.copyWith(bold: true));
        break;
      case 'WIFI_INFO':
        if (posController.wifiSsid.value.isNotEmpty) {
          bytes += generator.text(_normalizeString('Wi-Fi: ${posController.wifiSsid.value}'), styles: styles);
          bytes += generator.text(_normalizeString('Parol: ${posController.wifiPassword.value}'), styles: styles);
        }
        break;
      case 'KITCHEN_TITLE':
        bytes += generator.text(_normalizeString(element['props']?['title'] ?? '*** OSHXONA ***'), styles: _getStyles(element, defaultBold: true, defaultSize: PosTextSize.size2));
        break;
    }
    return bytes;
  }

  QRSize _getQRSize(String? size) {
    if (size == 'LARGE') return QRSize.size5;
    if (size == 'XLARGE') return QRSize.size6;
    return QRSize.size4;
  }

  List<int> _printSideBySide(Generator generator, Map<String, dynamic> elL, Map<String, dynamic> elR, POSController pos) {
    String getLabel(Map<String, dynamic> el) {
      if (el['type'] == 'INSTAGRAM_QR') return 'INSTAGRAM';
      if (el['type'] == 'TELEGRAM_QR') return 'TELEGRAM';
      if (el['type'] == 'WIFI_INFO') return 'WI-FI';
      return el['label'] ?? "";
    }

    final stylesL = _getStyles(elL);
    final stylesR = _getStyles(elR);

    return generator.row([
      PosColumn(text: _normalizeString(getLabel(elL)), width: 6, styles: stylesL.copyWith(align: PosAlign.center, bold: true)),
      PosColumn(text: _normalizeString(getLabel(elR)), width: 6, styles: stylesR.copyWith(align: PosAlign.center, bold: true)),
    ]);
  }

  List<int> _row(Generator g, String left, String right, {PosStyles? styles}) {
    final s = styles ?? const PosStyles();
    return g.row([
      PosColumn(text: _normalizeString(left), width: 7, styles: s),
      PosColumn(text: _normalizeString(right), width: 5, styles: s.copyWith(align: PosAlign.right)),
    ]);
  }

  Future<bool> printKitchenTicket(PrinterModel printer, Map<String, dynamic> order, List<dynamic> items, {String? title}) async {
    final orderForKitchen = Map<String, dynamic>.from(order);
    orderForKitchen['details'] = items;
    return await printReceipt(printer, orderForKitchen, title: title, isKitchenOnly: true);
  }

  Future<bool> printCancellationTicket(PrinterModel printer, Map<String, dynamic> order, List<dynamic> items, {String? title}) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty || items.isEmpty) return false;

    try {
      final profile = await _getProfile();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];

      // Large Header - Red-like warning (Capitalized and Bold)
      bytes += generator.feed(1);
      bytes += generator.text(_normalizeString(title != null ? '!!! $title !!!' : '!!! BEKOR QILINDI !!!'),
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      bytes += generator.hr(ch: '*');

      // Order & Table Info
      bytes += generator.text(_normalizeString('STOL: ${order['table']}'), 
          styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true, align: PosAlign.center));
      bytes += generator.text(_normalizeString('BUYURTMA: #${order['id']}'), 
          styles: const PosStyles(height: PosTextSize.size1, width: PosTextSize.size1, bold: true, align: PosAlign.center));
      
      bytes += generator.feed(1);
      bytes += generator.text(_normalizeString('VAQT: ${DateFormat('HH:mm').format(DateTime.now())}'), styles: const PosStyles(align: PosAlign.center));
      if (order['waiter_name'] != null && order['waiter_name'].toString().isNotEmpty) {
        bytes += generator.text(_normalizeString('AFITSANT: ${order['waiter_name']}'), styles: const PosStyles(align: PosAlign.center, bold: true));
      }
      bytes += generator.hr(ch: '-');

      // Cancelled Items
      for (var item in items) {
        bytes += generator.row([
          PosColumn(text: _normalizeString('${item['qty']} x'), width: 3, styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true)),
          PosColumn(text: _normalizeString('${item['name']}'), width: 9, styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size1, bold: true)),
        ]);
        bytes += generator.hr(ch: '-');
      }

      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(printer.ipAddress, printer.port,
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      
      return true;
    } catch (e) {
      print('Cancellation printing error: $e');
      return false;
    }
  }

  Future<bool> printTestPage(PrinterModel printer) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await _getProfile();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text('TEST PRINT',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      bytes += generator.text('Printer: ${printer.name}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('IP: ${printer.ipAddress}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Port: ${printer.port}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();
      bytes += generator.text('If you see this, your printer is working correctly.', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(printer.ipAddress, printer.port,
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print('Test print error: $e');
      return false;
    }
  }
}
