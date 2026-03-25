import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地推送通知服务（任务完成时通知用户）。
///
/// 使用方式：
/// ```dart
/// await PushNotificationService().init();
/// PushNotificationService().showTaskComplete('任务完成', '已成功执行您的指令');
/// ```
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._();
  PushNotificationService._();
  factory PushNotificationService() => _instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;

    // iOS / macOS：主动请求权限
    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// 展示一条本地推送（用于任务完成等场景）。
  Future<void> show({required String title, required String body}) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'dart_claw_task',
      '任务通知',
      channelDescription: 'AI 任务完成通知',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
