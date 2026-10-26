import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class AudioKeepAliveService {
  static AudioPlayer? _keepAlivePlayer;
  static AudioPlayer? _alarmPlayer;
  static bool _isRunning = false;

  /// 7/24 Arka Planda Canlı Tutucu (Silent Audio Loop)
  /// Ücretsiz Apple hesabı / Sideloadly kurulumlarında APNs sunucusu olmadan da
  /// Dart WebSocket dinleyicisinin ve soketlerin uyumasını engeller.
  static Future<void> startKeepAliveLoop() async {
    if (_isRunning) return;

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));

      _keepAlivePlayer ??= AudioPlayer();
      await _keepAlivePlayer!.setAsset('assets/audio/silence.wav');
      await _keepAlivePlayer!.setLoopMode(LoopMode.one);
      await _keepAlivePlayer!.setVolume(0.01); // Sıfıra yakın duyulmaz ses

      await _keepAlivePlayer!.play();
      _isRunning = true;
      print('[AudioKeepAlive] 7/24 Arka plan canlı tutma motoru başlatıldı.');
    } catch (e) {
      print('[AudioKeepAlive] Hata: $e');
    }
  }

  /// Sessiz Mod Delici Yüksek Sesli Alarm (Sabah Uyanma veya İhlal Uyarısı)
  /// AVAudioSessionCategory.playback kullanarak telefonun sessiz tuşu (Mute Switch)
  /// kapalı olsa bile alarmı maksimum güçte çalar.
  static Future<void> playLoudAlarm({Duration duration = const Duration(seconds: 10)}) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
      ));

      _alarmPlayer ??= AudioPlayer();
      // Çift ses oturumu
      await _alarmPlayer!.setAsset('assets/audio/silence.wav');
      await _alarmPlayer!.setVolume(1.0);
      await _alarmPlayer!.play();

      Future.delayed(duration, () {
        _alarmPlayer?.stop();
        // Sessiz keep-alive moduna geri dön
        startKeepAliveLoop();
      });
    } catch (e) {
      print('[AudioKeepAlive] Alarm çalma hatası: $e');
    }
  }

  static Future<void> stop() async {
    await _keepAlivePlayer?.stop();
    await _alarmPlayer?.stop();
    _isRunning = false;
  }
}
