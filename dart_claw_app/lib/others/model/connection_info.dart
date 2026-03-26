import 'package:shared_preferences/shared_preferences.dart';

/// 持久化最近一次连接信息的单例。
///
/// 读取：await ConnectionInfo().load();
/// 保存：await ConnectionInfo().save();
/// 清空：await ConnectionInfo().clear();
class ConnectionInfo {
  static final ConnectionInfo _instance = ConnectionInfo._();
  ConnectionInfo._();
  factory ConnectionInfo() => _instance;

  // ── 直连字段 ──────────────────────────────────────────────────────────────
  String host = '127.0.0.1';
  int port = 37788;
  String code = '';

  // ── 中继字段 ──────────────────────────────────────────────────────────────
  String relayHost = '';
  int relayPort = 37789;
  String relayCode = '';

  // ── 上次使用的 tab（0=scan, 1=manual, 2=relay） ───────────────────────────
  int lastTab = 0;

  // ── 内部 key ──────────────────────────────────────────────────────────────
  static const _kHost = 'ci_host';
  static const _kPort = 'ci_port';
  static const _kCode = 'ci_code';
  static const _kRelayHost = 'ci_relay_host';
  static const _kRelayPort = 'ci_relay_port';
  static const _kRelayCode = 'ci_relay_code';
  static const _kLastTab = 'ci_last_tab';

  /// 从持久化存储中读取字段，覆盖当前内存值。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    host = prefs.getString(_kHost) ?? host;
    port = prefs.getInt(_kPort) ?? port;
    code = prefs.getString(_kCode) ?? code;
    relayHost = prefs.getString(_kRelayHost) ?? relayHost;
    relayPort = prefs.getInt(_kRelayPort) ?? relayPort;
    relayCode = prefs.getString(_kRelayCode) ?? relayCode;
    lastTab = prefs.getInt(_kLastTab) ?? lastTab;
  }

  /// 把当前内存值持久化。
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_kHost, host),
      prefs.setInt(_kPort, port),
      prefs.setString(_kCode, code),
      prefs.setString(_kRelayHost, relayHost),
      prefs.setInt(_kRelayPort, relayPort),
      prefs.setString(_kRelayCode, relayCode),
      prefs.setInt(_kLastTab, lastTab),
    ]);
  }

  /// 清空所有持久化字段并重置为默认值。
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kHost),
      prefs.remove(_kPort),
      prefs.remove(_kCode),
      prefs.remove(_kRelayHost),
      prefs.remove(_kRelayPort),
      prefs.remove(_kRelayCode),
      prefs.remove(_kLastTab),
    ]);
    host = '127.0.0.1';
    port = 37788;
    code = '';
    relayHost = '';
    relayPort = 37789;
    relayCode = '';
    lastTab = 0;
  }
}
