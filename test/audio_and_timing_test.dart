import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kittentts_flutter/kittentts_flutter.dart';
import 'package:kittentts_flutter/src/engine/sentence_splitter.dart';
import 'package:kittentts_flutter/src/engine/timestamp_joiner.dart';

void main() {
  test('wavData returns a RIFF WAVE file', () {
    final result = KittenTTSResult(
      samples: Float32List.fromList([0, 0.5, -0.5]),
      sampleRate: outputSampleRate,
      voice: 'bella',
      effectiveSpeed: 1,
      inputText: 'hello',
    );

    final wav = result.wavData();
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(wav.length, 50);
  });

  test('splitSentences avoids common abbreviation breaks', () {
    expect(
      splitSentences('Dr. Rivera arrived. Fig. 2 changed.'),
      ['Dr. Rivera arrived. Fig. 2 changed.'],
    );
  });

  test('joinTimestamps maps phoneme durations to words', () {
    final timings =
        joinTimestamps('hello world', 'ab cd', [3, 1, 2, 1, 3, 4, 0]);
    expect(timings.length, 2);
    expect(timings[0].word, 'hello');
    expect(timings[0].startTime, 0);
    expect(timings[1].word, 'world');
  });
}
