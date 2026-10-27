import 'dart:async';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class WalkieAudioService {
  static bool _isRecording = false;

  static bool get isRecording => _isRecording;

  /// Gerçek Mikrofon Ses Kaydını Başlatır
  static Future<bool> startRecording() async {
    try {
      if (kIsWeb) {
        _isRecording = true;
        js.context.callMethod('startRealVoiceRecording');
        return true;
      }
      return false;
    } catch (e) {
      print('[WalkieAudioService.startRecording] Hata: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Ses Kaydını Durdurur ve Base64 Data URL (data:audio/webm;base64,...) formatında döndürür
  static Future<String?> stopRecording() async {
    try {
      if (kIsWeb) {
        _isRecording = false;
        // JS Promise'ini tetikle
        js.context.callMethod('stopRealVoiceRecording');
        // Kısa bir bekleme ile Base64 verisini al
        await Future.delayed(const Duration(milliseconds: 300));
        final dynamic raw = js.context.callMethod('getLastRecordedAudio');
        if (raw != null && raw.toString().isNotEmpty) {
          return raw.toString();
        }
      }
      return null;
    } catch (e) {
      print('[WalkieAudioService.stopRecording] Hata: $e');
      return null;
    }
  }

  /// Kaydedilen Gerçek Sesi veya Verilen Ses URL'sini Oynatır
  static void playAudio(String audioUrl) {
    try {
      if (kIsWeb) {
        js.context.callMethod('playRealAudio', [audioUrl]);
      }
    } catch (e) {
      print('[WalkieAudioService.playAudio] Hata: $e');
    }
  }

  /// Oynatılan Sesi Durdurur
  static void stopAudio() {
    try {
      if (kIsWeb) {
        js.context.callMethod('stopRealAudio');
      }
    } catch (e) {}
  }
}
