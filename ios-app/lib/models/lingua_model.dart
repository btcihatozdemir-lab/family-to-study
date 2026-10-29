class LinguaModel {
  final String id;
  final String langCode;
  final String word;
  final String meaning;
  final String? etymology;
  final String sampleSentence;
  final String quizQuestion;
  final String correctOption;
  final String optionB;
  final String optionC;

  LinguaModel({
    required this.id,
    required this.langCode,
    required this.word,
    required this.meaning,
    this.etymology,
    required this.sampleSentence,
    required this.quizQuestion,
    required this.correctOption,
    required this.optionB,
    required this.optionC,
  });

  factory LinguaModel.fromJson(Map<String, dynamic> json) {
    return LinguaModel(
      id: json['id']?.toString() ?? '',
      langCode: json['lang_code']?.toString() ?? 'tr',
      word: json['word']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      etymology: json['etymology']?.toString(),
      sampleSentence: json['sample_sentence']?.toString() ?? '',
      quizQuestion: json['quiz_question']?.toString() ?? '',
      correctOption: json['correct_option']?.toString() ?? '',
      optionB: json['option_b']?.toString() ?? '',
      optionC: json['option_c']?.toString() ?? '',
    );
  }

  List<String> get shuffledOptions {
    final list = [correctOption, optionB, optionC];
    list.shuffle();
    return list;
  }
}
