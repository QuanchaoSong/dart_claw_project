import 'package:dart_claw_core/dart_claw_core.dart';
import 'package:dart_claw_mouse_auto/dart_claw_mouse_auto.dart';

// ─── MouseMoveTool ────────────────────────────────────────────────────────────

/// 将鼠标光标移动到屏幕上的指定坐标。
class MouseMoveTool implements ClawTool {
  const MouseMoveTool();

  @override
  String get name => 'mouse_move';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Move the mouse cursor to the specified screen coordinates. '
              'Coordinates are in screen points; (0, 0) is the top-left of the '
              'primary display. Use screenshot + vision_read_image first to '
              'identify the target position.',
          'parameters': {
            'type': 'object',
            'properties': {
              'x': {
                'type': 'number',
                'description': 'Horizontal position in screen points.',
              },
              'y': {
                'type': 'number',
                'description': 'Vertical position in screen points.',
              },
            },
            'required': ['x', 'y'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();
    MouseController.moveTo(x, y);
    return ToolResult.success('Mouse moved to ($x, $y)');
  }
}

// ─── MouseClickTool ───────────────────────────────────────────────────────────

/// 在屏幕指定位置执行鼠标点击（移动 + 点击一步完成）。
class MouseClickTool implements ClawTool {
  const MouseClickTool();

  @override
  String get name => 'mouse_click';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Click the mouse at the specified screen coordinates. '
              'Moves the cursor and clicks in one step. '
              'Supports left, right, and middle buttons, as well as double-click.',
          'parameters': {
            'type': 'object',
            'properties': {
              'x': {
                'type': 'number',
                'description': 'Horizontal position in screen points.',
              },
              'y': {
                'type': 'number',
                'description': 'Vertical position in screen points.',
              },
              'button': {
                'type': 'string',
                'enum': ['left', 'right', 'center'],
                'description': 'Mouse button to use. Default is "left".',
              },
              'double_click': {
                'type': 'boolean',
                'description':
                    'If true, performs a double-click. Default is false.',
              },
            },
            'required': ['x', 'y'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();
    final buttonStr = args['button'] as String? ?? 'left';
    final isDouble = args['double_click'] as bool? ?? false;

    final button = switch (buttonStr) {
      'right' => MouseButton.right,
      'center' => MouseButton.center,
      _ => MouseButton.left,
    };

    if (isDouble) {
      MouseController.doubleClick(x, y, button: button);
    } else {
      MouseController.click(x, y, button: button);
    }

    final desc = isDouble ? 'Double-clicked' : 'Clicked';
    return ToolResult.success('$desc $buttonStr button at ($x, $y)');
  }
}

// ─── MouseDragTool ────────────────────────────────────────────────────────────

/// 从一个位置拖拽到另一个位置。
class MouseDragTool implements ClawTool {
  const MouseDragTool();

  @override
  String get name => 'mouse_drag';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Click and drag from one screen position to another. '
              'Useful for moving windows, selecting text ranges, or dragging UI elements.',
          'parameters': {
            'type': 'object',
            'properties': {
              'from_x': {'type': 'number', 'description': 'Drag start X.'},
              'from_y': {'type': 'number', 'description': 'Drag start Y.'},
              'to_x': {'type': 'number', 'description': 'Drag end X.'},
              'to_y': {'type': 'number', 'description': 'Drag end Y.'},
            },
            'required': ['from_x', 'from_y', 'to_x', 'to_y'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final fx = (args['from_x'] as num).toDouble();
    final fy = (args['from_y'] as num).toDouble();
    final tx = (args['to_x'] as num).toDouble();
    final ty = (args['to_y'] as num).toDouble();
    await MouseController.drag(fx, fy, tx, ty);
    return ToolResult.success('Dragged from ($fx, $fy) to ($tx, $ty)');
  }
}

// ─── MouseScrollTool ──────────────────────────────────────────────────────────

/// 在指定位置滚动鼠标滚轮。
class MouseScrollTool implements ClawTool {
  const MouseScrollTool();

  @override
  String get name => 'mouse_scroll';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Scroll the mouse wheel at the specified position. '
              'Positive delta_y scrolls down; negative scrolls up. '
              'Positive delta_x scrolls right; negative scrolls left.',
          'parameters': {
            'type': 'object',
            'properties': {
              'x': {'type': 'number', 'description': 'Scroll position X.'},
              'y': {'type': 'number', 'description': 'Scroll position Y.'},
              'delta_y': {
                'type': 'integer',
                'description': 'Vertical scroll amount in lines. Negative = up.',
              },
              'delta_x': {
                'type': 'integer',
                'description':
                    'Horizontal scroll amount in lines. Negative = left. Default 0.',
              },
            },
            'required': ['x', 'y', 'delta_y'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final x = (args['x'] as num).toDouble();
    final y = (args['y'] as num).toDouble();
    final dy = (args['delta_y'] as num).toInt();
    final dx = (args['delta_x'] as num? ?? 0).toInt();
    MouseController.scroll(x, y, deltaY: dy, deltaX: dx);
    return ToolResult.success('Scrolled at ($x, $y): dy=$dy, dx=$dx');
  }
}

// ─── KeyboardTypeTool ─────────────────────────────────────────────────────────

/// 向当前焦点控件注入文字（支持任意 Unicode，含中文）。
class KeyboardTypeTool implements ClawTool {
  const KeyboardTypeTool();

  @override
  String get name => 'keyboard_type';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Type text into the currently focused UI element. '
              'Supports any Unicode text including Chinese, emoji, and symbols. '
              'Click the target input field with mouse_click before calling this.',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {
                'type': 'string',
                'description': 'The text to type.',
              },
              'char_delay_ms': {
                'type': 'integer',
                'description':
                    'Delay between each character in milliseconds. '
                    'Default is 30. Increase if characters are dropped.',
              },
            },
            'required': ['text'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final text = args['text'] as String;
    final delay = (args['char_delay_ms'] as num? ?? 30).toInt();
    await KeyboardController.typeText(text, charDelayMs: delay);
    return ToolResult.success(
      'Typed ${text.length} character(s): "${_preview(text)}"',
    );
  }

  static String _preview(String text) =>
      text.length <= 40 ? text : '${text.substring(0, 40)}…';
}

// ─── KeyboardShortcutTool ─────────────────────────────────────────────────────

/// 执行系统键盘快捷键（Cmd+C / Cmd+V / Cmd+A 等）。
class KeyboardShortcutTool implements ClawTool {
  const KeyboardShortcutTool();

  @override
  String get name => 'keyboard_shortcut';

  @override
  bool get isDangerous => false;

  @override
  Map<String, dynamic> get definition => {
        'type': 'function',
        'function': {
          'name': name,
          'description':
              'Execute a keyboard shortcut or special key press. '
              'Use named shortcuts like "cmd+c", "cmd+v", "cmd+a", "cmd+z", '
              '"cmd+s", "cmd+w", "return", "escape", "tab", "backspace", '
              '"up", "down", "left", "right", "page_up", "page_down", '
              '"home", "end". '
              'For arbitrary combinations use the "keys" field with an array '
              'of modifier+key strings, e.g. ["cmd", "shift", "z"].',
          'parameters': {
            'type': 'object',
            'properties': {
              'shortcut': {
                'type': 'string',
                'description':
                    'Named shortcut string such as "cmd+c", "escape", "return", '
                    '"tab", "backspace", "delete", "up", "down", "left", "right", '
                    '"page_up", "page_down", "home", "end", "cmd+a", "cmd+z", '
                    '"cmd+shift+z", "cmd+s", "cmd+w", "cmd+t", "cmd+r".',
              },
            },
            'required': ['shortcut'],
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final shortcut = (args['shortcut'] as String).toLowerCase().trim();
    _dispatch(shortcut);
    return ToolResult.success('Executed shortcut: $shortcut');
  }

  static void _dispatch(String shortcut) {
    switch (shortcut) {
      // ── Common named shortcuts ─────────────────────────────────────────
      case 'cmd+a': KeyboardController.selectAll();
      case 'cmd+c': KeyboardController.copy();
      case 'cmd+x': KeyboardController.cut();
      case 'cmd+v': KeyboardController.paste();
      case 'cmd+z': KeyboardController.undo();
      case 'cmd+shift+z': KeyboardController.redo();
      case 'cmd+s': KeyboardController.shortcut(KeyCode.s, CGEventFlags.command);
      case 'cmd+w': KeyboardController.shortcut(KeyCode.w, CGEventFlags.command);
      case 'cmd+t': KeyboardController.shortcut(KeyCode.t, CGEventFlags.command);
      case 'cmd+r': KeyboardController.shortcut(KeyCode.r, CGEventFlags.command);
      case 'cmd+q': KeyboardController.shortcut(KeyCode.q, CGEventFlags.command);
      case 'cmd+n': KeyboardController.shortcut(KeyCode.n, CGEventFlags.command);
      case 'cmd+f': KeyboardController.shortcut(KeyCode.f, CGEventFlags.command);
      case 'cmd+h': KeyboardController.shortcut(KeyCode.h, CGEventFlags.command);
      case 'cmd+m': KeyboardController.shortcut(KeyCode.m, CGEventFlags.command);
      // ── Special keys ──────────────────────────────────────────────────
      case 'return' || 'enter': KeyboardController.pressReturn();
      case 'escape' || 'esc': KeyboardController.pressEscape();
      case 'tab': KeyboardController.pressTab();
      case 'backspace' || 'delete': KeyboardController.pressBackspace();
      case 'forward_delete': KeyboardController.pressForwardDelete();
      case 'space': KeyboardController.keyPress(KeyCode.space);
      // ── Arrow keys ────────────────────────────────────────────────────
      case 'up': KeyboardController.pressArrow(KeyCode.upArrow);
      case 'down': KeyboardController.pressArrow(KeyCode.downArrow);
      case 'left': KeyboardController.pressArrow(KeyCode.leftArrow);
      case 'right': KeyboardController.pressArrow(KeyCode.rightArrow);
      // ── Navigation ────────────────────────────────────────────────────
      case 'page_up': KeyboardController.keyPress(KeyCode.pageUp);
      case 'page_down': KeyboardController.keyPress(KeyCode.pageDown);
      case 'home': KeyboardController.keyPress(KeyCode.home);
      case 'end': KeyboardController.keyPress(KeyCode.end);
      // ── Text editing ──────────────────────────────────────────────────
      case 'cmd+left': KeyboardController.pressArrow(KeyCode.leftArrow, modifiers: CGEventFlags.command);
      case 'cmd+right': KeyboardController.pressArrow(KeyCode.rightArrow, modifiers: CGEventFlags.command);
      case 'cmd+shift+left': KeyboardController.pressArrow(KeyCode.leftArrow, modifiers: CGEventFlags.command | CGEventFlags.shift);
      case 'cmd+shift+right': KeyboardController.pressArrow(KeyCode.rightArrow, modifiers: CGEventFlags.command | CGEventFlags.shift);
    }
  }
}
