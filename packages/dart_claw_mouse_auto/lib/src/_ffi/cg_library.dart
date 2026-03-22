import 'dart:ffi';
import 'cg_types.dart';

// ─── Native function typedefs ─────────────────────────────────────────────────

// void CGWarpMouseCursorPosition(CGPoint newCursorPosition)
typedef _CGWarpMouseC = Void Function(CGPoint point);
typedef _CGWarpMouseDart = void Function(CGPoint point);

// CGEventRef CGEventCreateMouseEvent(
//   CGEventSourceRef source, CGEventType mouseType,
//   CGPoint mouseCursorPosition, CGMouseButton mouseButton)
typedef _CGEventCreateMouseC = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  Int32 type,
  CGPoint point,
  Int32 button,
);
typedef _CGEventCreateMouseDart = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  int type,
  CGPoint point,
  int button,
);

// void CGEventPost(CGEventTapLocation tap, CGEventRef event)
typedef _CGEventPostC = Void Function(Int32 tap, Pointer<CGEventOpaque> event);
typedef _CGEventPostDart = void Function(int tap, Pointer<CGEventOpaque> event);

// void CGEventSetFlags(CGEventRef event, CGEventFlags flags)
typedef _CGEventSetFlagsC = Void Function(
    Pointer<CGEventOpaque> event, Uint64 flags);
typedef _CGEventSetFlagsDart = void Function(
    Pointer<CGEventOpaque> event, int flags);

// CGEventRef CGEventCreateScrollWheelEvent(
//   CGEventSourceRef source, CGScrollEventUnit units,
//   uint32_t wheelCount, int32_t wheel1)
// Note: variadic – we fix wheelCount=1 and declare only wheel1.
typedef _CGScrollWheelC = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  Int32 units,
  Uint32 wheelCount,
  Int32 wheel1,
);
typedef _CGScrollWheelDart = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  int units,
  int wheelCount,
  int wheel1,
);

// Same but with an extra wheel2 (horizontal scroll)
typedef _CGScrollWheelXYC = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  Int32 units,
  Uint32 wheelCount,
  Int32 wheel1,
  Int32 wheel2,
);
typedef _CGScrollWheelXYDart = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  int units,
  int wheelCount,
  int wheel1,
  int wheel2,
);

// void CFRelease(CFTypeRef cf)
typedef _CFReleaseC = Void Function(Pointer<Void> cf);
typedef _CFReleaseDart = void Function(Pointer<Void> cf);

// ─── Keyboard ─────────────────────────────────────────────────────────────────

// CGEventRef CGEventCreateKeyboardEvent(
//   CGEventSourceRef source, uint16_t virtualKey, bool keyDown)
typedef _CGEventCreateKeyboardC = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  Uint16 virtualKey,
  Bool keyDown,
);
typedef _CGEventCreateKeyboardDart = Pointer<CGEventOpaque> Function(
  Pointer<CGEventSource> source,
  int virtualKey,
  bool keyDown,
);

// void CGEventKeyboardSetUnicodeString(
//   CGEventRef event, size_t stringLength, const UniChar *unicodeString)
typedef _CGEventKeyboardSetUnicodeStringC = Void Function(
  Pointer<CGEventOpaque> event,
  Size stringLength,
  Pointer<Uint16> unicodeString,
);
typedef _CGEventKeyboardSetUnicodeStringDart = void Function(
  Pointer<CGEventOpaque> event,
  int stringLength,
  Pointer<Uint16> unicodeString,
);

// ─── Library singleton ────────────────────────────────────────────────────────

/// Loads the ApplicationServices framework and resolves all CGEvent symbols.
/// Use [CgLibrary.instance].
final class CgLibrary {
  CgLibrary._() {
    final lib = DynamicLibrary.open(
      '/System/Library/Frameworks/ApplicationServices.framework/'
      'ApplicationServices',
    );

    warpMouse =
        lib.lookupFunction<_CGWarpMouseC, _CGWarpMouseDart>(
      'CGWarpMouseCursorPosition',
    );

    createMouseEvent =
        lib.lookupFunction<_CGEventCreateMouseC, _CGEventCreateMouseDart>(
      'CGEventCreateMouseEvent',
    );

    postEvent =
        lib.lookupFunction<_CGEventPostC, _CGEventPostDart>(
      'CGEventPost',
    );

    setFlags =
        lib.lookupFunction<_CGEventSetFlagsC, _CGEventSetFlagsDart>(
      'CGEventSetFlags',
    );

    createScrollEventY =
        lib.lookupFunction<_CGScrollWheelC, _CGScrollWheelDart>(
      'CGEventCreateScrollWheelEvent',
    );

    createScrollEventXY =
        lib.lookupFunction<_CGScrollWheelXYC, _CGScrollWheelXYDart>(
      'CGEventCreateScrollWheelEvent',
    );

    cfRelease =
        lib.lookupFunction<_CFReleaseC, _CFReleaseDart>(
      'CFRelease',
    );

    createKeyboardEvent =
        lib.lookupFunction<_CGEventCreateKeyboardC, _CGEventCreateKeyboardDart>(
      'CGEventCreateKeyboardEvent',
    );

    keyboardSetUnicodeString = lib.lookupFunction<
        _CGEventKeyboardSetUnicodeStringC,
        _CGEventKeyboardSetUnicodeStringDart>(
      'CGEventKeyboardSetUnicodeString',
    );
  }

  static final CgLibrary instance = CgLibrary._();

  late final _CGWarpMouseDart warpMouse;
  late final _CGEventCreateMouseDart createMouseEvent;
  late final _CGEventPostDart postEvent;
  late final _CGEventSetFlagsDart setFlags;
  late final _CGScrollWheelDart createScrollEventY;
  late final _CGScrollWheelXYDart createScrollEventXY;
  late final _CFReleaseDart cfRelease;
  late final _CGEventCreateKeyboardDart createKeyboardEvent;
  late final _CGEventKeyboardSetUnicodeStringDart keyboardSetUnicodeString;
}
