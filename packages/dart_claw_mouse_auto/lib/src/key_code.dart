/// macOS virtual key codes (kVK_* constants from Carbon HIToolbox/Events.h).
///
/// Use these with [KeyboardController.keyPress], [KeyboardController.keyDown],
/// [KeyboardController.keyUp], and [KeyboardController.shortcut].
///
/// For typing text, prefer [KeyboardController.typeText] — it uses Unicode
/// injection and does not require knowing key codes.
abstract final class KeyCode {
  // ─── Letters ────────────────────────────────────────────────────────────────
  static const int a = 0;
  static const int s = 1;
  static const int d = 2;
  static const int f = 3;
  static const int h = 4;
  static const int g = 5;
  static const int z = 6;
  static const int x = 7;
  static const int c = 8;
  static const int v = 9;
  static const int b = 11;
  static const int q = 12;
  static const int w = 13;
  static const int e = 14;
  static const int r = 15;
  static const int y = 16;
  static const int t = 17;
  static const int o = 31;
  static const int u = 32;
  static const int i = 34;
  static const int p = 35;
  static const int l = 37;
  static const int j = 38;
  static const int k = 40;
  static const int n = 45;
  static const int m = 46;

  // ─── Numbers (main keyboard row) ─────────────────────────────────────────
  static const int one = 18;
  static const int two = 19;
  static const int three = 20;
  static const int four = 21;
  static const int five = 23;
  static const int six = 22;
  static const int seven = 26;
  static const int eight = 28;
  static const int nine = 25;
  static const int zero = 29;

  // ─── Punctuation / symbols ────────────────────────────────────────────────
  static const int minus = 27;
  static const int equal = 24;
  static const int leftBracket = 33;
  static const int rightBracket = 30;
  static const int backslash = 42;
  static const int semicolon = 41;
  static const int quote = 39;
  static const int grave = 50;   // ` ~
  static const int comma = 43;
  static const int period = 47;
  static const int slash = 44;

  // ─── Special / control ────────────────────────────────────────────────────
  static const int returnKey = 36;
  static const int tab = 48;
  static const int space = 49;
  static const int delete = 51;        // Backspace
  static const int forwardDelete = 117;
  static const int escape = 53;
  static const int home = 115;
  static const int end = 119;
  static const int pageUp = 116;
  static const int pageDown = 121;

  // ─── Arrow keys ───────────────────────────────────────────────────────────
  static const int leftArrow = 123;
  static const int rightArrow = 124;
  static const int downArrow = 125;
  static const int upArrow = 126;

  // ─── Modifier keys (for keyDown/keyUp, not needed with CGEventSetFlags) ──
  static const int command = 55;
  static const int shift = 56;
  static const int capsLock = 57;
  static const int option = 58;     // Alt
  static const int control = 59;
  static const int rightShift = 60;
  static const int rightOption = 61;
  static const int rightControl = 62;
  static const int function = 63;

  // ─── Function keys ────────────────────────────────────────────────────────
  static const int f1 = 122;
  static const int f2 = 120;
  static const int f3 = 99;
  static const int f4 = 118;
  static const int f5 = 96;
  static const int f6 = 97;
  static const int f7 = 98;
  static const int f8 = 100;
  static const int f9 = 101;
  static const int f10 = 109;
  static const int f11 = 103;
  static const int f12 = 111;
  static const int f13 = 105;
  static const int f14 = 107;
  static const int f15 = 113;
  static const int f16 = 106;
  static const int f17 = 64;
  static const int f18 = 79;
  static const int f19 = 80;
  static const int f20 = 90;

  // ─── Keypad ───────────────────────────────────────────────────────────────
  static const int keypad0 = 82;
  static const int keypad1 = 83;
  static const int keypad2 = 84;
  static const int keypad3 = 85;
  static const int keypad4 = 86;
  static const int keypad5 = 87;
  static const int keypad6 = 88;
  static const int keypad7 = 89;
  static const int keypad8 = 91;
  static const int keypad9 = 92;
  static const int keypadDecimal = 65;
  static const int keypadMultiply = 67;
  static const int keypadPlus = 69;
  static const int keypadClear = 71;
  static const int keypadDivide = 75;
  static const int keypadEnter = 76;
  static const int keypadMinus = 78;
  static const int keypadEquals = 81;
}
