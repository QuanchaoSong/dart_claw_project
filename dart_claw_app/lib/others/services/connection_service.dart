import 'package:get/get.dart';

/// 单例：管理与桌面端（dart_claw）的 WebSocket 连接状态。
/// 访问方式：ConnectionService().xxx
class ConnectionService {
  static final ConnectionService _instance = ConnectionService._();
  ConnectionService._();
  factory ConnectionService() => _instance;

  final isConnected = false.obs;
  final serverHost = ''.obs;
  final serverPort = 7788.obs;

  String get serverUrl => 'ws://${serverHost.value}:${serverPort.value}';

  /// 尝试连接，成功返回 true。
  /// WebSocket 逻辑将在后续实现。
  Future<bool> connect({required String host, required int port}) async {
    serverHost.value = host;
    serverPort.value = port;
    // TODO: establish WebSocket connection
    isConnected.value = true;
    return true;
  }

  void disconnect() {
    // TODO: close WebSocket
    isConnected.value = false;
  }
}
