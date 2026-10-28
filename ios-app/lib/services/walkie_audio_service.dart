import 'dart:async';
import 'package:flutter/foundation.dart';
import 'js_interop/js_bridge.dart';

class WalkieAudioService {
  static bool _isRecording = false;

  static bool get isRecording => _isRecording;

  /// Gerçek Mikrofon Ses Kaydını Başlatır
  static Future<bool> startRecording() async {
    try {
      if (kIsWeb) {
        _isRecording = true;
        JSBridge.callMethod('startRealVoiceRecording');
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
        JSBridge.callMethod('stopRealVoiceRecording');
        // Kısa bir bekleme ile Base64 verisini al
        await Future.delayed(const Duration(milliseconds: 300));
        final dynamic raw = JSBridge.getMethod('getLastRecordedAudio');
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
        JSBridge.callMethod('playRealAudio', [audioUrl]);
      }
    } catch (e) {
      print('[WalkieAudioService.playAudio] Hata: $e');
    }
  }

  /// Oynatılan Sesi Durdurur
  static void stopAudio() {
    try {
      if (kIsWeb) {
        JSBridge.callMethod('stopRealAudio');
      }
    } catch (e) {}
  }
}
