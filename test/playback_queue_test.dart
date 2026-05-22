import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kittentts_flutter/kittentts_flutter.dart';

void main() {
  test('PlaybackQueue plays generated results sequentially', () async {
    final plays = <String>[];
    final completions = <Completer<void>>[];
    final queue = PlaybackQueue(
      generate: (text, {voice, speed}) async => _result(text),
      play: (result, [options = const AudioPlayOptions()]) async {
        plays.add(result.inputText);
        options.onPlaybackStart?.call();
        final completion = Completer<void>();
        completions.add(completion);
        await completion.future;
      },
      stop: () async {},
    );

    final first = queue.enqueue(_result('first'));
    final second = queue.enqueue(_result('second'));
    await _waitFor(() => plays.length == 1);

    expect(queue.length, 2);
    expect(queue.pendingCount, 1);
    expect(queue.isPlaying, isTrue);

    completions.removeAt(0).complete();
    await first;
    await _waitFor(() => plays.length == 2);

    expect(queue.length, 1);
    expect(queue.pendingCount, 0);

    completions.removeAt(0).complete();
    await second;
    expect(queue.length, 0);
    expect(queue.isPlaying, isFalse);
  });

  test('PlaybackQueue enqueueText generates only at the front', () async {
    final events = <String>[];
    final completions = <Completer<void>>[];
    final queue = PlaybackQueue(
      generate: (text, {voice, speed}) async {
        events.add('generate:$text');
        return _result(text);
      },
      play: (result, [options = const AudioPlayOptions()]) async {
        events.add('play:${result.inputText}');
        final completion = Completer<void>();
        completions.add(completion);
        await completion.future;
      },
      stop: () async {},
    );

    final first = queue.enqueueText('first');
    final second = queue.enqueueText('second');
    await _waitFor(() => events.length == 2);

    expect(events, ['generate:first', 'play:first']);

    completions.removeAt(0).complete();
    await first;
    await _waitFor(() => events.length == 4);

    expect(events, [
      'generate:first',
      'play:first',
      'generate:second',
      'play:second',
    ]);

    completions.removeAt(0).complete();
    await second;
  });
}

KittenTTSResult _result(String text) {
  return KittenTTSResult(
    samples: Float32List.fromList([0]),
    sampleRate: outputSampleRate,
    voice: 'bella',
    effectiveSpeed: 1,
    inputText: text,
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (DateTime.now().isBefore(deadline)) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for condition');
}
