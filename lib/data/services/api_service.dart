import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart' as g;
import '../../logic/pos_controller.dart' as logic;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final GetStorage _storage = GetStorage();
  String? _token;

  ApiService._internal() {
    final String baseUrl = _storage.read('api_url') ?? 'https://cafe-backend-code-production.up.railway.app';
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _token = _storage.read('access_token');
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null && !options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          final detail = e.response?.data?['detail'];
          if (detail == "Qurilma o'zgargani sababli tizimdan chiqdingiz") {
             try {
                g.Get.find<logic.POSController>().logout(forced: true);
             } catch (_) {}
          }
        }
        return handler.next(e);
      }
    ));
  }

  void setBaseUrl(String url) {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    _storage.write('api_url', url);
    _dio.options.baseUrl = url;
    print("API Base URL set to: $url");
  }

  String get currentBaseUrl => _dio.options.baseUrl;
  static String get baseUrl => ApiService().currentBaseUrl;

  void setToken(String? token) {
    _token = token;
    _storage.write('access_token', token);
  }

  void restoreTerminalToken() {
    _token = _storage.read('terminal_token');
    _storage.write('access_token', _token);
  }

  void clearTerminalToken() {
    _storage.remove('terminal_token');
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password, {String? deviceId, String? deviceName}) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_name': deviceName,
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginTerminal(String username, String password) async {
    try {
      final response = await _dio.post('/auth/terminal/login', data: {
        'username': username,
        'password': password,
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      _storage.write('terminal_token', _token); 
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithPin(String userId, String pinCode, {String? deviceId, String? deviceName}) async {
    try {
      final response = await _dio.post('/auth/login/pin', data: {
        'user_id': userId,
        'pin_code': pinCode,
        'device_id': deviceId ?? 'pos_terminal_default',
        'device_name': deviceName ?? 'POS Device',
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStaffQRToken(String userId) async {
    try {
      final response = await _dio.get('/auth/qr-token/$userId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithQR(String qrToken, {String? deviceId, String? deviceName}) async {
    try {
      final response = await _dio.post('/auth/login/qr', data: {
        'token': qrToken,
        'device_id': deviceId,
        'device_name': deviceName,
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getTerminalStaff() async {
    try {
      // Use terminal token specifically for this request if available
      String? tToken = _storage.read('terminal_token');
      Options? options;
      if (tToken != null) {
        options = Options(headers: {'Authorization': 'Bearer $tToken'});
      }
      
      final response = await _dio.get('/auth/terminal/staff', options: options);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getStaffPublic(String cafeId) async {
    try {
      final response = await _dio.get('/auth/staff-public/$cafeId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    try {
      final response = await _dio.post('/auth/location', data: {
        'lat': lat,
        'lng': lng,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Categories
  Future<List<dynamic>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/categories/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategory(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/categories/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _dio.delete('/categories/$id');
    } catch (e) {
      rethrow;
    }
  }

  // Products
  Future<List<dynamic>> getProducts() async {
    try {
      final response = await _dio.get('/products');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/products/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/products/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/products/$id');
    } catch (e) {
      rethrow;
    }
  }

  // Orders
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _dio.post('/orders', data: orderData);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateOrder(int orderId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/orders/$orderId', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getOrders() async {
    try {
      final response = await _dio.get('/orders');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      final backendStatus = status.toUpperCase().replaceAll(" ", "_");
      await _dio.patch('/orders/$orderId/status', data: {'status': backendStatus});
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadImage(String filePath) async {
    try {
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post('/uploads/', data: formData);
      return response.data['url'];
    } catch (e) {
      rethrow;
    }
  }

  // Preparation Areas
  Future<List<dynamic>> getPreparationAreas() async {
    try {
      final response = await _dio.get('/preparation-areas');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPreparationArea(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/preparation-areas', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePreparationArea(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/preparation-areas/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePreparationArea(String id) async {
    try {
      await _dio.delete('/preparation-areas/$id');
    } catch (e) {
      rethrow;
    }
  }

  // Printers
  Future<List<dynamic>> getPrinters() async {
    try {
      final response = await _dio.get('/printers');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPrinter(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/printers', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePrinter(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/printers/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePrinter(String id) async {
    try {
      await _dio.delete('/printers/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await _dio.get('/cafes/subscription-status');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCafe(String id) async {
    try {
      final response = await _dio.get('/cafes/$id');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Tables & Floor Plan
  Future<List<dynamic>> getTableAreas() async {
    try {
      final response = await _dio.get('/table-areas');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTableArea(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/table-areas/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getTables() async {
    try {
      final response = await _dio.get('/tables');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTablePosition(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/tables/$id/position', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTable(String id, Map<String, dynamic> data) async {
    try {
       final response = await _dio.put('/tables/$id', data: data);
       return response.data;
    } catch (e) {
       rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCafe(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/cafes/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLatestVersion() async {
    try {
      final response = await _dio.get('/system/version');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Users
  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _dio.get('/users');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/users/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/users/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _dio.delete('/users/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getTerminals() async {
    try {
      final response = await _dio.get('/terminals');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}
