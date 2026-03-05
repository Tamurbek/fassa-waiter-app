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

  String _formatPrice(dynamic amount) {
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat("#,###", "en_US");
    return formatter.format(value).replaceAll(',', ' ');
  }

  String _normalizeString(String? text) {
    if (text == null) return "";
    Map<String, String> replacements = {
      'Е': 'E', 'е': 'e', 'А': 'A', 'а': 'a', 'В': 'B', 'С': 'C', 'с': 'c',
      'Н': 'H', 'К': 'K', 'к': 'k', 'М': 'M', 'м': 'm', 'О': 'O', 'о': 'o',
      'Р': 'P', 'р': 'p', 'Т': 'T', 'Х': 'X', 'х': 'x', 'У': 'Y', 'у': 'y',
    };
    String result = text;
    replacements.forEach((key, value) => result = result.replaceAll(key, value));
    return result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  Future<bool> printReceipt(PrinterModel printer, Map<String, dynamic> order, {String? title, bool isKitchenOnly = false}) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];
      final posController = Get.find<POSController>();

      final layout = isKitchenOnly 
          ? posController.kitchenReceiptLayout.toList() 
          : posController.receiptLayout.toList();

      if (layout.isEmpty) {
        // Fallback for empty layout
        bytes += generator.text(_normalizeString(posController.restaurantName.value), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
        bytes += generator.hr();
        bytes += generator.text(_normalizeString('ID: ${order['id']}'), styles: const PosStyles(align: PosAlign.center));
        bytes += generator.feed(1);
        final items = order['details'] as List;
        for (var item in items) {
          bytes += _row(generator, item['name'], '${item['qty']} x ${_formatPrice(item['price'])}');
        }
        bytes += generator.hr();
        bytes += _row(generator, 'JAMI:', _formatPrice(order['total']), bold: true);
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
          bytes += await _printElement(generator, element, order, posController, printer, title);
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

  Future<List<int>> _printElement(Generator generator, Map<String, dynamic> element, Map<String, dynamic> order, POSController posController, PrinterModel printer, String? title) async {
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
        if (order['table'] != null && order['table'] != '-') {
            bytes += generator.text(_normalizeString('STOL: ${order['table']}'), styles: _getStyles(element, defaultBold: true, defaultSize: PosTextSize.size2));
        }
        break;
      case 'ITEMS_TABLE':
        bytes += generator.hr(ch: '-');
        bytes += generator.row([
          PosColumn(text: _normalizeString('NOMI'), width: 7, styles: styles.copyWith(bold: true)),
          PosColumn(text: _normalizeString('SONI'), width: 2, styles: styles.copyWith(bold: true, align: PosAlign.center)),
          PosColumn(text: _normalizeString('NARXI'), width: 3, styles: styles.copyWith(bold: true, align: PosAlign.right)),
        ]);
        bytes += generator.hr(ch: '-');
        final items = order['details'] as List;
        for (var item in items) {
          bytes += generator.row([
            PosColumn(text: _normalizeString(item['name']), width: 7, styles: styles),
            PosColumn(text: _normalizeString(item['qty'].toString()), width: 2, styles: styles.copyWith(align: PosAlign.center)),
            PosColumn(text: _normalizeString(_formatPrice((item['price'] as num) * (item['qty'] as num))), width: 3, styles: styles.copyWith(align: PosAlign.right)),
          ]);
        }
        bytes += generator.hr(ch: '-');
        break;
      case 'TOTAL_BLOCK':
        bytes += _row(generator, 'JAMI:', _formatPrice(order['total']), styles: styles.copyWith(bold: true));
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
      final profile = await CapabilityProfile.load();
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
      final profile = await CapabilityProfile.load();
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
