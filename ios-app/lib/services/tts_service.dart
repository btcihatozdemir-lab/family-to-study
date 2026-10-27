import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class TTSService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      if (kIsWeb) {
        // Web ortamında doğrudan en kaliteli tarayıcı ses sentezleyicisini kullanıyoruz
        _isInitialized = true;
        return;
      }

      await _tts.setLanguage('tr-TR');
      // Mobil cihazlar için doğal konuşma parametreleri
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5); // iOS AVFoundation'da 0.5 tam normal konuşma hızıdır
      await _tts.setVolume(1.0);

      // Türkçe sesleri ara ve en kalitelisini seç
      try {
        final voices = await _tts.getVoices;
        if (voices is List) {
          for (final v in voices) {
            if (v is Map) {
              final name = (v['name'] ?? '').toString().toLowerCase();
              final locale = (v['locale'] ?? '').toString().toLowerCase();
              if (locale.contains('tr') && (name.contains('google') || name.contains('yelda') || name.contains('natural') || name.contains('emel'))) {
                await _tts.setVoice({'name': v['name'], 'locale': v['locale']});
                break;
              }
            }
          }
        }
      } catch (_) {}

      _isInitialized = true;
    } catch (e) {
      print('[TTSService] Başlatma hatası: $e');
    }
  }

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      if (kIsWeb) {
        // Web Speech API ile en berrak Türkçe ses
        try {
          js.context.callMethod('playTurkishSpeech', [text]);
          return;
        } catch (e) {
          print('[TTSService Web JS] Hata: $e, fallback çalışıyor.');
        }
      }

      await init();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      print('[TTSService] Seslendirme hatası: $e');
    }
  }

  static Future<void> announceTomorrowBag({
    required String studentName,
    required String dayName,
    required List<String> lessons,
    required List<String> materials,
  }) async {
    String lessonText = lessons.isNotEmpty
        ? lessons.join(', ')
        : 'Özel bir ders programı bulunmuyor';

    String materialText = materials.isNotEmpty
        ? 'Ayrıca çantana ${materials.join(', ')} koymayı unutma.'
        : 'Ders kitaplarını ve defterlerini çantana yerleştirmeyi unutma.';

    String fullSpeech =
        'Merhaba $studentName! Yarın $dayName. Yarınki derslerin: $lessonText. $materialText Çantan hazır olduğunda harika bir gün seni bekliyor!';

    await speak(fullSpeech);
  }

  static Future<void> stop() async {
    try {
      if (kIsWeb) {
        try {
          js.context.callMethod('stopTurkishSpeech');
        } catch (_) {}
      }
      await _tts.stop();
    } catch (_) {}
  }
}

typedef TtsService = TTSService;
