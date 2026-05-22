import '../kitten_word_timing.dart';
import 'text_cleaner.dart';
import 'text_preprocessor.dart';

List<KittenWordTiming> joinTimestamps(
  String inputText,
  String phonemes,
  List<num> durations,
) {
  final phonemeGroups =
      phonemes.split(' ').where((part) => part.isNotEmpty).toList();
  if (phonemeGroups.isEmpty || durations.length < 3) return const [];

  final words =
      inputText.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return const [];

  final groupTimings = _computePhonemeGroupTimings(phonemeGroups, durations);
  if (groupTimings.isEmpty) return const [];

  final groupCounts = _allocateGroupsToWords(words, groupTimings.length);
  final timings = <KittenWordTiming>[];
  var groupIndex = 0;

  for (var wordIndex = 0;
      wordIndex < words.length && groupIndex < groupTimings.length;
      wordIndex += 1) {
    final remainingWords = words.length - wordIndex - 1;
    final remainingGroups = groupTimings.length - groupIndex;
    final groupsForWord = [
      groupCounts[wordIndex],
      remainingGroups - remainingWords,
    ].reduce((a, b) => a < b ? a : b).clamp(1, remainingGroups);
    final startGroup = groupTimings[groupIndex];
    final endGroup = groupTimings[groupIndex + groupsForWord - 1];
    timings.add(
      KittenWordTiming(
        wordIndex: wordIndex,
        word: words[wordIndex],
        startTime: startGroup.startTime,
        endTime: groupsForWord > 1 ? endGroup.cursorEndTime : endGroup.endTime,
      ),
    );
    groupIndex += groupsForWord;
  }

  return timings;
}

List<_PhonemeGroupTiming> _computePhonemeGroupTimings(
  List<String> phonemeGroups,
  List<num> durations,
) {
  const magicDivisor = 80.0;
  final timings = <_PhonemeGroupTiming>[];
  var left = 2 * (durations[0] - 3).clamp(0, double.infinity).toDouble();
  var right = left;
  var durationIndex = 1;

  for (var groupIndex = 0; groupIndex < phonemeGroups.length; groupIndex += 1) {
    final group = phonemeGroups[groupIndex];
    final phonemeCount = _encodedTokenCount(group);
    if (durationIndex + phonemeCount > durations.length) break;
    final startTime = left / magicDivisor;
    var tokenDuration = 0.0;
    for (var i = durationIndex; i < durationIndex + phonemeCount; i += 1) {
      tokenDuration += durations[i].toDouble();
    }

    final hasSpace = groupIndex < phonemeGroups.length - 1;
    final spaceDuration =
        hasSpace && durationIndex + phonemeCount < durations.length
            ? durations[durationIndex + phonemeCount].toDouble()
            : 0.0;
    left = right + 2 * tokenDuration + spaceDuration;
    final endTime = left / magicDivisor;
    right = left + spaceDuration;

    timings.add(
      _PhonemeGroupTiming(
        startTime: startTime,
        endTime: endTime,
        cursorEndTime: right / magicDivisor,
      ),
    );
    durationIndex += phonemeCount + (hasSpace ? 1 : 0);
  }
  return timings;
}

int _encodedTokenCount(String phonemeGroup) =>
    encodePhonemes(phonemeGroup).length - 3;

List<int> _allocateGroupsToWords(List<String> words, int groupCount) {
  final counts = List<int>.filled(words.length, 1);
  var extraGroups = (groupCount - words.length).clamp(0, groupCount);
  if (extraGroups == 0 || words.isEmpty) return counts;
  final estimates = words.map(_estimateGroupCountForWord).toList();

  for (var index = 0; index < counts.length && extraGroups > 0; index += 1) {
    final available = estimates[index] - counts[index];
    if (available <= 0) continue;
    final add = available < extraGroups ? available : extraGroups;
    counts[index] += add;
    extraGroups -= add;
  }
  if (extraGroups > 0) counts[counts.length - 1] += extraGroups;
  return counts;
}

int _estimateGroupCountForWord(String word) {
  final core = word
      .replaceFirst(RegExp(r'^[^\p{L}\p{N}$€£¥]+', unicode: true), '')
      .replaceFirst(RegExp(r'[^\p{L}\p{N}%]+$', unicode: true), '');
  if (core.isEmpty) return 1;
  if (RegExp(r'^[A-Z]{2,}$').hasMatch(core)) return core.length;
  final inlineAcronym = RegExp(r'^[A-Z]?[a-z]+([A-Z]{2,})$').firstMatch(core);
  if (inlineAcronym != null) return 1 + inlineAcronym.group(1)!.length;
  final visibleParts = core
      .split(RegExp(r'[-‐‑‒–—/]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (visibleParts.length > 1) {
    return visibleParts
        .map(_estimateGroupCountForWord)
        .fold(0, (sum, value) => sum + value);
  }
  return preprocess(core)
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .length
      .clamp(1, 1000);
}

class _PhonemeGroupTiming {
  const _PhonemeGroupTiming({
    required this.startTime,
    required this.endTime,
    required this.cursorEndTime,
  });

  final double startTime;
  final double endTime;
  final double cursorEndTime;
}
