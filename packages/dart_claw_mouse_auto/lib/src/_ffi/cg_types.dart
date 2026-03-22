import 'dart:ffi';

// ─── Structs ─────────────────────────────────────────────────────────────────

/// Mirrors `CGPoint { CGFloat x; CGFloat y; }` (CGFloat == double on 64-bit).
final class CGPoint extends Struct {
  @Double()
  external double x;

  @Double()
  external double y;
}

// ─── Opaque handles ───────────────────────────────────────────────────────────

/// Opaque `CGEventRef` (Core Foundation object).
final class CGEventOpaque extends Opaque {}

/// Opaque `CGEventSourceRef` (pass `nullptr` to use the default source).
final class CGEventSource extends Opaque {}

// ─── CGEventType constants ────────────────────────────────────────────────────

abstract final class CGEventType {
  static const int null_ = 0;
  static const int leftMouseDown = 1;
  static const int leftMouseUp = 2;
  static const int rightMouseDown = 3;
  static const int rightMouseUp = 4;
  static const int mouseMoved = 5;
  static const int leftMouseDragged = 6;
  static const int rightMouseDragged = 7;
  static const int otherMouseDown = 25;
  static const int otherMouseUp = 26;
  static const int otherMouseDragged = 27;
  static const int scrollWheel = 22;
}

// ─── CGMouseButton constants ──────────────────────────────────────────────────

abstract final class CGMouseButton {
  static const int left = 0;
  static const int right = 1;
  static const int center = 2;
}

// ─── CGEventTapLocation constants ────────────────────────────────────────────

abstract final class CGEventTapLocation {
  /// Posted at the HID system level — closest to hardware, affects all apps.
  static const int hidEventTap = 0;

  /// Posted at the session level.
  static const int sessionEventTap = 1;

  /// Posted at the annotated-session level.
  static const int annotatedSessionEventTap = 2;
}

// ─── CGScrollEventUnit constants ─────────────────────────────────────────────

abstract final class CGScrollEventUnit {
  static const int pixel = 0;
  static const int line = 1;
}

// ─── CGEventFlags (modifier mask) ────────────────────────────────────────────

abstract final class CGEventFlags {
  static const int alphaShift = 0x00010000;
  static const int shift = 0x00020000;
  static const int control = 0x00040000;
  static const int alternate = 0x00080000; // Option
  static const int command = 0x00100000;
  static const int numericPad = 0x00200000;
  static const int help = 0x00400000;
  static const int secondaryFn = 0x00800000;
}
