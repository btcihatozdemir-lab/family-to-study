import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setPitch(1.05); // Çocuklar için samimi ve enerjik ton
      await _tts.setSpeechRate(0.5); // Anlaşılır ve sakin tempo
      await _tts.setVolume(1.0);
      _isInitialized = true;
    } catch (e) {
      print('[TTSService] Başlatma hatası: $e');
    }
  }

  static Future<void> speak(String text) async {
    try {
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
        ? 'Ek olarak çantana ${materials.join(', ')} koymayı unutma.'
        : 'Tüm defter ve kitaplarını çantana yerleştirmeyi unutma.';

    String fullSpeech =
        'Hey $studentName! Yarın $dayName. Yarınki derslerin: $lessonText. $materialText Harika bir gün seni bekliyor!';

    await speak(fullSpeech);
  }

  static Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

typedef TtsService = TTSService;

