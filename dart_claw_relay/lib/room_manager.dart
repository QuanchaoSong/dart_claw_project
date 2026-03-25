import 'dart:io';
import 'relay_room.dart';

/// 管理所有中继房间的生命周期。
///
/// 房间以 roomId（字符串）为 key；roomId 由客户端在连接时通过 query
/// 参数 `room` 指定，通常等同于安全码，也可以是任意不可猜测的随机串。
class RoomManager {
  final _rooms = <String, RelayRoom>{};

  int get roomCount => _rooms.length;

  // ── 对外接口 ────────────────────────────────────────────────────────────

  /// 桌面端（host）连接。
  void onHostConnect(String roomId, WebSocket ws) {
    final room = _rooms.putIfAbsent(roomId, RelayRoom.new);
    room.setHost(ws, onClose: () => _cleanup(roomId));
    _log('host connected  room="$roomId"  rooms=${_rooms.length}');
  }

  /// 移动端（guest）连接。若对应房间尚无 host，拒绝连接。
  void onGuestConnect(String roomId, WebSocket ws) {
    final room = _rooms[roomId];
    if (room == null || !room.hasHost) {
      ws.add('{"type":"error","message":"No host available for room \\"$roomId\\""}');
      ws.close(4001, 'No host');
      _log('guest rejected  room="$roomId" (no host)');
      return;
    }
    room.addGuest(ws, onClose: () => _cleanup(roomId));
    _log('guest connected  room="$roomId"  rooms=${_rooms.length}');
  }

  // ── 内部工具 ────────────────────────────────────────────────────────────

  void _cleanup(String roomId) {
    final room = _rooms[roomId];
    if (room != null && room.isEmpty) {
      _rooms.remove(roomId);
      _log('room cleaned up room="$roomId"  rooms=${_rooms.length}');
    }
  }

  static void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    print('[$ts][RoomManager] $msg');
  }
}
