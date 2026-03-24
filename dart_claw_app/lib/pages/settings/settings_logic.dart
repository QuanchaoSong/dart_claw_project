import 'package:get/get.dart';
import '../../others/services/connection_service.dart';
import '../connection/connection_page.dart';

class SettingsLogic extends GetxController {
  ConnectionService get _conn => ConnectionService();

  String get serverUrl => _conn.serverUrl;
  bool get isConnected => _conn.isConnected.value;

  void disconnect() {
    _conn.disconnect();
    Get.offAll(() => ConnectionPage());
  }
}
