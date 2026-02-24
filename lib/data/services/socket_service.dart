import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  late IO.Socket socket;
  
  // Singleton
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal() {
    _initSocket();
  }

  String? _cafeId;

  void setCafeId(String id) {
    _cafeId = id;
    if (socket.connected) {
      socket.emit('joinRoom', {'cafe_id': id});
    }
  }

  void _initSocket() {
    socket = IO.io(ApiService.baseUrl, 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setQuery({'client': 'mobile'})
        .enableAutoConnect()
        .build()
    );

    socket.onConnect((_) {
      print('WebSocket connected: ${socket.id}');
      if (_cafeId != null) {
        socket.emit('joinRoom', {'cafe_id': _cafeId});
      }
    });

    socket.onDisconnect((_) {
      print('WebSocket disconnected');
    });

    socket.on('error', (err) => print('Socket Error: $err'));
    socket.onConnectError((err) => print('Connection Error: $err'));
  }

  void onNewOrder(Function(dynamic) callback) {
    socket.on('newOrder', (data) => callback(data));
  }

  void onOrderStatusUpdated(Function(dynamic) callback) {
    socket.on('orderStatusUpdated', (data) => callback(data));
  }

  void onDataUpdated(Function(dynamic) callback) {
    socket.on('dataUpdated', (data) => callback(data));
  }

  void emitPrintRequest(Map<String, dynamic> data) {
    if (_cafeId != null) {
      data['cafe_id'] = _cafeId;
    }
    socket.emit('printRequest', data);
  }

  void onPrintRequest(Function(dynamic) callback) {
    socket.on('printRequest', (data) => callback(data));
  }

  void emitTableLock(String tableId, String userName) {
    socket.emit('tableLock', {
      'tableId': tableId, 
      'user': userName,
      'cafe_id': _cafeId,
    });
  }

  void emitTableUnlock(String tableId) {
    socket.emit('tableUnlock', {
      'tableId': tableId,
      'cafe_id': _cafeId,
    });
  }

  void onTableLockStatus(Function(dynamic) callback) {
    socket.on('tableLockStatus', (data) => callback(data));
  }

  void onWaiterCall(Function(dynamic) callback) {
    socket.on('waiterCall', (data) => callback(data));
  }

  void emitCallWaiter(Map<String, dynamic> data) {
    if (_cafeId != null) {
      data['cafe_id'] = _cafeId;
    }
    socket.emit('callWaiter', data);
  }

  void disconnect() {
    socket.disconnect();
  }
}
