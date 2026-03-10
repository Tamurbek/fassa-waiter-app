import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../../data/models/food_item.dart';
import '../../data/models/printer_model.dart';
import '../../data/models/preparation_area_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/socket_service.dart';
import '../../data/services/printer_service.dart';
import '../../data/services/update_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

abstract class POSControllerState extends GetxController {
  final storage = GetStorage();
  final api = ApiService();
  final socket = SocketService();
  final printerService = PrinterService();
  final updateService = UpdateService();
  final audioPlayer = AudioPlayer();
  final uuid = const Uuid();
  
  var isOnline = true.obs;
  var syncQueue = <Map<String, dynamic>>[].obs; // Queue of tasks to sync
  var navIndex = 0.obs;

  
  var currentOrder = <Map<String, dynamic>>[].obs;
  var allOrders = <Map<String, dynamic>>[].obs;
  var currentUser = Rxn<Map<String, dynamic>>();
  var currentTerminal = Rxn<Map<String, dynamic>>();
  var pinCode = RxnString();
  var isPinAuthenticated = false.obs;
  var isPrinting = false.obs;
  var isSubmitting = false.obs;
  var deviceRole = RxnString(); // "ADMIN", "CASHIER", "WAITER"
  var waiterCafeId = RxnString(); // Used only for WAITER role
  var printedKitchenQuantities = <String, Map<String, int>>{}.obs; // "orderId": {"productId": qty}
  final Map<String, DateTime> processedPrintIds = {};
  
  // Order modes, current selection, table, and editing state
  final List<String> orderModes = ["Dine-in", "Takeaway", "Delivery"];
  var currentMode = "Dine-in".obs;
  
  // Product Catalog
  var products = <FoodItem>[].obs;
  var categories = <String>["All"].obs;
  var categoriesObjects = <Map<String, dynamic>>[].obs;
  var preparationAreas = <PreparationAreaModel>[].obs;
  var printers = <PrinterModel>[].obs;
  var selectedCategory = "All".obs;
  var searchQuery = "".obs;
  var users = <Map<String, dynamic>>[].obs;

  List<FoodItem> get filteredProducts {
    var list = (selectedCategory.value == "All"
        ? products
        : products.where((p) => p.category == selectedCategory.value).toList())
        .where((p) => p.isAvailable).toList();

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(query)).toList();
    }
    return list;
  }

  var selectedTable = "".obs;
  var lockedTables = <String, String>{}.obs; // {"tableId": "userName"}
  var editingOrderId = RxnString(); // Track if we are editing an existing order
  String originalOrderJson = ""; // To check if any changes were made
  var isOrderModified = false.obs;

  // Settings
  var printerPaperSize = "80mm".obs;
  var autoPrintReceipt = false.obs;
  var restaurantName = "".obs;
  var restaurantAddress = "".obs;
  var restaurantPhone = "".obs;
  var restaurantLogo = "".obs;
  var currency = "UZS".obs;
  String get currencySymbol => currency.value == 'USD' ? '\$' : "so'm";
  var serviceFeeDineIn = 10.0.obs;
  var serviceFeeTakeaway = 0.0.obs;
  var serviceFeeDelivery = 3000.0.obs;
  
  // Receipt Settings
  var receiptStyle = "STANDARD".obs;
  var receiptHeader = "".obs;
  var receiptFooter = "Xaridingiz uchun rahmat!".obs;
  var showLogo = true.obs;
  var showWaiter = true.obs;
  var showWifi = false.obs;
  var wifiSsid = "".obs;
  var wifiPassword = "".obs;
  var instagram = "".obs;
  var telegram = "".obs;
  var instagramLink = "".obs;
  var telegramLink = "".obs;
  var showInstagramQr = false.obs;
  var showPhoneOnReceipt = true.obs;
  var allowWaiterMobileOrders = true.obs;
  var receiptLayout = <Map<String, dynamic>>[].obs;
  var kitchenReceiptLayout = <Map<String, dynamic>>[].obs;
  var workStartTime = "00:00".obs;
  var workEndTime = "23:59".obs;

  // Feature Flags (from backend)
  var isGeofencingEnabled = true.obs;
  var isShiftBroadcastEnabled = true.obs;
  var isTableManagementEnabled = true.obs;
  var isKitchenPrintEnabled = true.obs;
  var isSubscriptionEnforced = true.obs;
  var isQrLoginEnabled = true.obs;
  var isOfflineSyncEnabled = true.obs;
  var isStockTrackingEnabled = true.obs;

  // Printing Toggles
  var enableKitchenPrint = true.obs;
  var enableBillPrint = true.obs;
  var enablePaymentPrint = true.obs;
  var isDarkMode = false.obs;
  var isFullScreen = false.obs;
  var isAutoStart = false.obs;

  var isOrdersTableView = false.obs;

  var tableAreas = <String>[].obs;
  var tablesByArea = <String, List<String>>{}.obs;

  var tableAreaBackendIds = <String, String>{}; // "Zal": "area_uuid"
  var tableAreaDetails = <String, Map<String, dynamic>>{}.obs; // "Zal": {"width_m": 12.0, "height_m": 8.0}
  var selectedWaiter = RxnString(); // Track selected waiter for order assignment (Cashier/Admin)

  var tablePositions = <String, Map<String, double>>{}.obs; // "Location-TableId": {"x": 100.0, "y": 200.0}
  var tableProperties = <String, Map<String, dynamic>>{}.obs; // width, height, shape
  var tableBackendIds = <String, String>{}; // "Location-TableId": "backend_uuid"
  var isEditMode = false.obs;

  // Subscription
  var subscriptionDaysLeft = RxnInt();    // null = VIP (cheksiz)
  var isSubscriptionExpired = false.obs;
  var isVip = false.obs;
  var subscriptionEndDate = RxnString();  // ISO string or null
  Timer? subscriptionTimer;
  Timer? locationTimer;
  var isWithinGeofence = true.obs;

  // Role helpers
  bool get isAdmin => currentUser.value?['role'] == "CAFE_ADMIN" || currentUser.value?['role'] == "SYSTEM_ADMIN";
  bool get isWaiter => currentUser.value?['role'] == "WAITER";
  bool get isCashier => currentUser.value?['role'] == "CASHIER";

  String get cafeId {
    final userCafeId = currentUser.value?['cafe_id'];
    if (userCafeId != null) return userCafeId.toString();
    final terminalCafeId = currentTerminal.value?['cafe_id'];
    if (terminalCafeId != null) return terminalCafeId.toString();
    return waiterCafeId.value ?? "";
  }

  void toggleOrdersViewMode() {
    isOrdersTableView.value = !isOrdersTableView.value;
  }

  void setEnableKitchenPrint(bool value) {
    enableKitchenPrint.value = value;
    storage.write('enable_kitchen_print', value);
  }

  void setEnableBillPrint(bool value) {
    enableBillPrint.value = value;
    storage.write('enable_bill_print', value);
  }

  void setEnablePaymentPrint(bool value) {
    enablePaymentPrint.value = value;
    storage.write('enable_payment_print', value);
  }

  // Abstract/Bridge methods that mixins will implement or call
  Future<void> fetchBackendData();
  void saveAllOrders();
  void saveProducts();
  void saveCategories();
  void savePreparationAreas();
  void savePrinters();
  void checkIfModified();
  void clearCurrentOrder();
  Future<void> printOrder(Map<String, dynamic> order, {bool isKitchenOnly = false, String? receiptTitle});
  Future<void> printLocally(Map<String, dynamic> order, {bool isKitchenOnly = false, String? receiptTitle});
  bool addToSyncQueue(String type, Map<String, dynamic> data);
  Future<void> processSyncQueue();
}
