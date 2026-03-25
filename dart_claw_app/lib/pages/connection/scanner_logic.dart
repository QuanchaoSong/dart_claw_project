import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerLogic extends GetxController {
  final scannerController = MobileScannerController();
  final hasError = false.obs;
  final errorMsg = ''.obs;

  bool _detected = false;

  @override
  void onClose() {
    scannerController.dispose();
    super.onClose();
  }

  void onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || (uri.scheme != 'ws' && uri.scheme != 'http')) return;
    _detected = true;
    scannerController.stop();
    Get.back(result: raw);
  }

  void onScanError(MobileScannerException error) {
    if (hasError.value) return;
    hasError.value = true;
    errorMsg.value = error.errorDetails?.message ?? '当前设备不支持扫码（如模拟器）';
  }
}
