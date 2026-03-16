import 'package:get/get.dart';

class HomeLogic extends GetxController {
  // 右侧面板显示状态
  final showInfoPanel = true.obs;

  // 切换右侧面板
  void toggleInfoPanel() {
    showInfoPanel.value = !showInfoPanel.value;
  }

  @override
  void onReady() {
    super.onReady();
  }
}
