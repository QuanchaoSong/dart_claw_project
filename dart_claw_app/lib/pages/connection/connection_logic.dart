import 'dart:io';

import 'package:dart_claw_app/others/tool/hud_tool.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../others/model/connection_info.dart';
import '../../others/services/connection_service.dart';
import '../chat/chat_page.dart';

class ConnectionLogic extends GetxController {
  final hostController = TextEditingController(text: '127.0.0.1');
  final portController = TextEditingController(text: '37788');
  final codeController = TextEditingController();

  // ── 中继模式字段 ──────────────────────────────────────────────────────────
  final relayHostController = TextEditingController();
  final relayPortController = TextEditingController(text: '37789');
  final relayCodeController = TextEditingController();

  final isConnecting = false.obs;
  final errorMessage = RxnString();
  final selectedTab = 0.obs; // 0 = scan, 1 = manual, 2 = relay

  @override
  void onReady() {
    super.onReady();
    _loadSavedInfo();
    _warmupConnection();
  }

  Future<void> _loadSavedInfo() async {
    await ConnectionInfo().load();
    final info = ConnectionInfo();
    hostController.text = info.host;
    portController.text = '${info.port}';
    codeController.text = info.code;
    relayHostController.text = info.relayHost;
    relayPortController.text = '${info.relayPort}';
    relayCodeController.text = info.relayCode;
    selectedTab.value = info.lastTab;
  }

  /// 触发 iOS "允许使用无线数据" 权限弹窗。
  /// 必须在连接操作前执行，否则 errno=65。
  void _warmupConnection() {
    if (!Platform.isIOS) return;
    HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..getUrl(Uri.parse('https://www.apple.com'))
          .then((req) => req.close())
          .then((res) => res.drain<void>())
          .catchError((_) {});
  }

  @override
  void onClose() {
    hostController.dispose();
    portController.dispose();
    codeController.dispose();
    relayHostController.dispose();
    relayPortController.dispose();
    relayCodeController.dispose();
    super.onClose();
  }

  Future<void> connectFromQr(String qrData) async {
    final uri = Uri.tryParse(qrData);
    if (uri == null || uri.host.isEmpty) {
      HudTool.showInfo('无效的二维码数据');
      return;
    };

    // relay://host:port?room=securityCode
    if (uri.scheme == 'relay') {
      relayHostController.text = uri.host;
      relayPortController.text = '${uri.port}';
      relayCodeController.text = uri.queryParameters['room'] ?? '';
      selectedTab.value = 2;
      await connectRelay();
      return;
    }

    // ws://host:port?code=securityCode （直连模式）
    if (uri.port == 0) return;
    hostController.text = uri.host;
    portController.text = '${uri.port}';
    codeController.text = uri.queryParameters['code'] ?? '';
    await connect();
  }

  Future<void> connect() async {
    final host = hostController.text.trim();
    final port = int.tryParse(portController.text.trim());
    if (host.isEmpty || port == null) {
      errorMessage.value = '请填写有效的 IP 和端口';
      return;
    }
    if (codeController.text.trim().isEmpty) {
      errorMessage.value = '请填写安全码';
      return;
    }

    final code = codeController.text.trim();
    isConnecting.value = true;
    errorMessage.value = null;
    try {
      final ok = await ConnectionService().connect(
        host: host,
        port: port,
        code: code,
      );
      if (ok) {
        final info = ConnectionInfo();
        info.host = host;
        info.port = port;
        info.code = code;
        info.lastTab = selectedTab.value;
        await info.save();
        Get.off(() => ChatPage(), transition: Transition.downToUp);
      } else {
        errorMessage.value = '连接失败，请检查 IP、端口和安全码';
        debugPrint('[ConnectionLogic] connect failed: host=$host port=$port');
      }
    } catch (e) {
      errorMessage.value = '连接失败: $e';
      debugPrint('[ConnectionLogic] connect error: $e');
    } finally {
      isConnecting.value = false;
    }
  }

  /// 通过中继服务器连接桌面端。
  Future<void> connectRelay() async {
    final host = relayHostController.text.trim();
    final port = int.tryParse(relayPortController.text.trim());
    final code = relayCodeController.text.trim();
    if (host.isEmpty || port == null) {
      errorMessage.value = '请填写有效的中继地址和端口';
      // HudTool.showInfo('请填写有效的中继地址和端口');
      return;
    }
    if (code.isEmpty) {
      errorMessage.value = '请填写安全码';
      // HudTool.showInfo('请填写安全码');
      return;
    }
    isConnecting.value = true;
    errorMessage.value = null;
    try {
      final ok = await ConnectionService().connect(
        host: '',
        port: 0,
        code: code,
        relay: true,
        relayHostAddr: host,
        relayPortNum: port,
      );
      if (ok) {
        final info = ConnectionInfo();
        info.relayHost = host;
        info.relayPort = port;
        info.relayCode = code;
        info.lastTab = selectedTab.value;
        await info.save();
        Get.off(() => ChatPage(), transition: Transition.downToUp);
      } else {
        errorMessage.value = '连接失败，请检查中继地址、端口和安全码';
        debugPrint('[ConnectionLogic] connectRelay failed: host=$host port=$port');
      }
    } catch (e) {
      errorMessage.value = '连接失败: $e';
      debugPrint('[ConnectionLogic] connectRelay error: $e');
    } finally {
      isConnecting.value = false;
    }
  }
}
