import 'package:dart_claw/others/constants/color_constants.dart';
import 'package:dart_claw/others/services/app_config_service.dart';
import 'package:dart_claw/others/server/local_server.dart';
import 'package:dart_claw/others/services/scheduler_service.dart';
import 'package:dart_claw/others/tool/database_tool.dart';
import 'package:dart_claw/pages/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // 初始化配置服务（读取 ~/.dart_claw/config.json）
  await Get.putAsync(() => AppConfigService().init());
  await DatabaseTool.shared.init();
  await SchedulerService.instance.init();
  if (AppConfigService.shared.config.value.server.isEnabled) {
    await LocalServer().start();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Dart Claw',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.bgMid,
          background: AppColors.bgDeep,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: HomePage(),
      builder: FlutterSmartDialog.init(
        builder: (context, widget) {
          return MediaQuery(
            //设置全局的文字的textScaleFactor为1.0，文字不再随系统设置改变
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: widget!,
          );
        },
      ),
    );
  }
}
