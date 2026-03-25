import 'dart:io';

/// 一个中继房间：持有一个桌面端（host）和若干移动端（guest），
/// 负责在它们之间双向透明地转发 WebSocket 帧。
class RelayRoom {
  WebSocket? _host;
  final _guests = <WebSocket>{};

  bool get hasHost => _host != null;

  /// 房间是否已无任何连接（可安全清理）。
  bool get isEmpty => _host == null && _guests.isEmpty;

  // ── Host ─────────────────────────────────────────────────────────────────

  /// 注册桌面端连接。同一房间只允许一个 host，后来者会踢掉旧的。
  void setHost(WebSocket ws, {required void Function() onClose}) {
    // 若已有旧 host，先断开
    final old = _host;
    if (old != null) {
      old.close(WebSocketStatus.goingAway, 'Replaced by new host');
    }
    _host = ws;

    ws.listen(
      (data) {
        // host → 所有 guest（广播）
        for (final g in List.of(_guests)) {
          _safeSend(g, data);
        }
      },
      onDone: () {
        _host = null;
        // 通知所有 guest：host 已断开
        for (final g in List.of(_guests)) {
          g.close(WebSocketStatus.goingAway, 'Host disconnected');
        }
        _guests.clear();
        onClose();
      },
      onError: (_) {
        _host = null;
        onClose();
      },
      cancelOnError: true,
    );
  }

  // ── Guest ─────────────────────────────────────────────────────────────────

  /// 注册移动端连接。
  void addGuest(WebSocket ws, {required void Function() onClose}) {
    _guests.add(ws);

    ws.listen(
      (data) {
        // guest → host（单播）
        final h = _host;
        if (h != null) _safeSend(h, data);
      },
      onDone: () {
        _guests.remove(ws);
        onClose();
      },
      onError: (_) {
        _guests.remove(ws);
        // 不调用 ws.close()，onError 后 socket 已失效
        onClose();
      },
      cancelOnError: true,
    );
  }

  // ── 内部工具 ────────────────────────────────────────────────────────────

  void _safeSend(WebSocket ws, dynamic data) {
    try {
      ws.add(data);
    } catch (_) {
      // 忽略发送错误；对端的 onDone/onError 会负责清理
    }
  }
}
