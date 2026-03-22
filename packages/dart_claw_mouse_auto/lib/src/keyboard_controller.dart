import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '_ffi/cg_library.dart';
import '_ffi/cg_types.dart';
import 'key_code.dart';

/// High-level keyboard automation API backed by CoreGraphics CGEvent.
///
/// **Typing text** (including Chinese, emoji, any Unicode):
/// ```dart
/// await KeyboardController.typeText('Hello, 世界!');
/// ```
///
/// **Virtual key presses** (navigation, special keys, shortcuts):
/// ```dart
/// KeyboardController.keyPress(KeyCode.returnKey);
/// KeyboardController.keyPress(KeyCode.tab);
/// KeyboardController.shortcut(KeyCode.c, CGEventFlags.command); // Cmd+C
/// KeyboardController.shortcut(KeyCode.a, CGEventFlags.command); // Cmd+A
/// ```
abstract final class KeyboardController {
  // ─── Text input ─────────────────────────────────────────────────────────────

  /// Type an arbitrary Unicode string, one code unit at a time.
  ///
  /// Uses `CGEventKeyboardSetUnicodeString` so **no key-code mapping is needed**
  /// — works for ASCII, CJK, emoji, and any other Unicode character.
  ///
  /// [charDelayMs] is the inter-character delay in milliseconds (default 30 ms).
  /// Reduce to 0 for maximum speed; increase if keystrokes are dropped.
  static Future<void> typeText(
    String text, {
    int charDelayMs = 30,
  }) async {
    final lib = CgLibrary.instance;
    final src = Pointer<CGEventSource>.fromAddress(0);
    final tap = CGEventTapLocation.hidEventTap;

    for (final codePoint in text.runes) {
      // Convert Unicode code point → UTF-16 code unit(s).
      final List<int> units;
      if (codePoint < 0x10000) {
        units = [codePoint];
      } else {
        // Supplementary plane (emoji, rare CJK): encode as surrogate pair.
        final adjusted = codePoint - 0x10000;
        units = [
          0xD800 + (adjusted >> 10),      // high surrogate
          0xDC00 + (adjusted & 0x3FF),    // low surrogate
        ];
      }

      using((arena) {
        final buf = arena<Uint16>(units.length);
        for (var i = 0; i < units.length; i++) {
          buf[i] = units[i];
        }

        final down = lib.createKeyboardEvent(src, 0, true);
        lib.keyboardSetUnicodeString(down, units.length, buf);
        lib.postEvent(tap, down);
        lib.cfRelease(down.cast());

        final up = lib.createKeyboardEvent(src, 0, false);
        lib.keyboardSetUnicodeString(up, units.length, buf);
        lib.postEvent(tap, up);
        lib.cfRelease(up.cast());
      });

      if (charDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: charDelayMs));
      }
    }
  }

  // ─── Virtual key press ──────────────────────────────────────────────────────

  /// Press and release a virtual key by its [KeyCode].
  ///
  /// [modifiers] is an optional bitmask of [CGEventFlags] constants.
  /// Example: `KeyboardController.keyPress(KeyCode.a, modifiers: CGEventFlags.command)`
  static void keyPress(int keyCode, {int modifiers = 0}) {
    _postKeyEvent(keyCode, keyDown: true, modifiers: modifiers);
    _postKeyEvent(keyCode, keyDown: false, modifiers: modifiers);
  }

  /// Hold a key down without releasing it.
  ///
  /// **Always pair with [keyUp] to avoid a stuck key.**
  static void keyDown(int keyCode, {int modifiers = 0}) {
    _postKeyEvent(keyCode, keyDown: true, modifiers: modifiers);
  }

  /// Release a previously held key.
  static void keyUp(int keyCode, {int modifiers = 0}) {
    _postKeyEvent(keyCode, keyDown: false, modifiers: modifiers);
  }

  // ─── Shortcut helpers ────────────────────────────────────────────────────────

  /// Press a key with one or more modifier keys.
  ///
  /// ```dart
  /// KeyboardController.shortcut(KeyCode.c, CGEventFlags.command);           // Cmd+C
  /// KeyboardController.shortcut(KeyCode.z, CGEventFlags.command);           // Cmd+Z
  /// KeyboardController.shortcut(KeyCode.v, CGEventFlags.command | CGEventFlags.shift); // Cmd+Shift+V
  /// ```
  static void shortcut(int keyCode, int modifiers) =>
      keyPress(keyCode, modifiers: modifiers);

  /// Select all (Cmd+A).
  static void selectAll() =>
      shortcut(KeyCode.a, CGEventFlags.command);

  /// Copy (Cmd+C).
  static void copy() =>
      shortcut(KeyCode.c, CGEventFlags.command);

  /// Cut (Cmd+X).
  static void cut() =>
      shortcut(KeyCode.x, CGEventFlags.command);

  /// Paste (Cmd+V).
  static void paste() =>
      shortcut(KeyCode.v, CGEventFlags.command);

  /// Undo (Cmd+Z).
  static void undo() =>
      shortcut(KeyCode.z, CGEventFlags.command);

  /// Redo (Cmd+Shift+Z).
  static void redo() =>
      shortcut(KeyCode.z, CGEventFlags.command | CGEventFlags.shift);

  /// Press Return/Enter.
  static void pressReturn() => keyPress(KeyCode.returnKey);

  /// Press Tab.
  static void pressTab() => keyPress(KeyCode.tab);

  /// Press Escape.
  static void pressEscape() => keyPress(KeyCode.escape);

  /// Press Backspace (Delete on Mac keyboard).
  static void pressBackspace() => keyPress(KeyCode.delete);

  /// Press the forward-delete key (fn+Delete on compact keyboards).
  static void pressForwardDelete() => keyPress(KeyCode.forwardDelete);

  /// Press an arrow key. Accepts [KeyCode.upArrow], [KeyCode.downArrow],
  /// [KeyCode.leftArrow], or [KeyCode.rightArrow].
  static void pressArrow(int arrowKeyCode, {int modifiers = 0}) =>
      keyPress(arrowKeyCode, modifiers: modifiers);

  // ─── Internal helpers ────────────────────────────────────────────────────────

  static void _postKeyEvent(
    int keyCode, {
    required bool keyDown,
    int modifiers = 0,
  }) {
    final lib = CgLibrary.instance;
    final src = Pointer<CGEventSource>.fromAddress(0);
    final tap = CGEventTapLocation.hidEventTap;

    final event = lib.createKeyboardEvent(src, keyCode, keyDown);
    if (modifiers != 0) lib.setFlags(event, modifiers);
    lib.postEvent(tap, event);
    lib.cfRelease(event.cast());
  }
}
