/// dart_claw_mouse_auto
///
/// macOS mouse automation via Dart FFI + CoreGraphics.
/// No compilation step required — loads the system ApplicationServices
/// framework at runtime.
///
/// Usage:
/// ```dart
/// import 'package:dart_claw_mouse_auto/dart_claw_mouse_auto.dart';
///
/// MouseController.moveTo(200, 300);
/// MouseController.click(200, 300);
/// MouseController.scroll(200, 300, deltaY: -3);
/// await MouseController.drag(100, 100, 400, 400);
/// ```
library dart_claw_mouse_auto;

export 'src/mouse_controller.dart' show MouseController, MouseButton;
export 'src/keyboard_controller.dart' show KeyboardController;
export 'src/key_code.dart' show KeyCode;
export 'src/_ffi/cg_types.dart' show CGEventFlags, CGScrollEventUnit;
