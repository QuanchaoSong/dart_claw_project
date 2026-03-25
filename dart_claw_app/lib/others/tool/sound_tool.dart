import 'package:audioplayers/audioplayers.dart';

/// 播放简短的提示音效（错误、需要确认、需要输入等场景）。
///
/// 音频文件放置在 assets/audio/ 目录下。
/// 使用方式：`SoundTool.play('alert.wav')`
class SoundTool {
  SoundTool._();

  static final AudioPlayer _player = AudioPlayer();

  /// 播放 assets/audio/ 下的音频文件。
  /// [fileName] 例如 'alert.wav'、'error.mp3'。
  static Future<void> play(String fileName) async {
    try {
      await _player.play(AssetSource('audio/$fileName'));
    } catch (_) {
      // 音频文件不存在或播放失败时静默忽略
    }
  }

  /// 释放资源（一般不需要调用，App 退出时自动释放）。
  static Future<void> dispose() async {
    await _player.dispose();
  }
}
