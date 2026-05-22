class KittenWordTiming {
  const KittenWordTiming({
    required this.wordIndex,
    required this.word,
    required this.startTime,
    required this.endTime,
  });

  final int wordIndex;
  final String word;
  final double startTime;
  final double endTime;

  KittenWordTiming copyWith({
    int? wordIndex,
    String? word,
    double? startTime,
    double? endTime,
  }) {
    return KittenWordTiming(
      wordIndex: wordIndex ?? this.wordIndex,
      word: word ?? this.word,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
