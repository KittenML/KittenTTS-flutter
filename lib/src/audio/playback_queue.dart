import 'dart:async';
import 'dart:collection';

import '../kitten_tts_result.dart';
import '../kitten_voice.dart';
import 'audio_output.dart';

typedef PlaybackQueueGenerate = Future<KittenTTSResult> Function(
  String text, {
  KittenTTSVoiceId? voice,
  double? speed,
});

typedef PlaybackQueuePlay = Future<void> Function(
  KittenTTSResult result, [
  AudioPlayOptions options,
]);

typedef PlaybackQueueStop = Future<void> Function();

/// FIFO playback queue for generated KittenTTS audio.
///
/// Each queued item waits for the previous item to finish before playback
/// starts. The configured [AudioPlayer.play] implementation should resolve
/// after playback finishes for strict sequencing.
class PlaybackQueue {
  PlaybackQueue({
    required PlaybackQueueGenerate generate,
    required PlaybackQueuePlay play,
    required PlaybackQueueStop stop,
  })  : _generate = generate,
        _play = play,
        _stop = stop;

  final PlaybackQueueGenerate _generate;
  final PlaybackQueuePlay _play;
  final PlaybackQueueStop _stop;
  final _tasks = Queue<_PlaybackQueueTask<dynamic>>();
  var _draining = false;
  var _isPlaying = false;

  int get length => _tasks.length + (_isPlaying ? 1 : 0);

  int get pendingCount => _tasks.length;

  bool get isPlaying => _isPlaying;

  /// Queue an already generated result for playback.
  Future<void> enqueue(
    KittenTTSResult result, [
    AudioPlayOptions options = const AudioPlayOptions(),
  ]) {
    return _add(() => _play(result, options));
  }

  /// Queue text for generation and playback.
  ///
  /// Generation starts only when this item reaches the front of the queue,
  /// which keeps output order stable when inputs have different generation
  /// costs.
  Future<KittenTTSResult> enqueueText(
    String text, {
    KittenTTSVoiceId? voice,
    double? speed,
    AudioPlayOptions options = const AudioPlayOptions(),
  }) {
    return _add(() async {
      final result = await _generate(text, voice: voice, speed: speed);
      await _play(result, options);
      return result;
    });
  }

  /// Reject queued items that have not started yet.
  void clear() {
    final error = StateError('Playback queue was cleared.');
    while (_tasks.isNotEmpty) {
      _tasks.removeFirst().completeError(error);
    }
  }

  /// Clear pending items and stop the active player.
  Future<void> stop() async {
    clear();
    await _stop();
  }

  Future<T> _add<T>(Future<T> Function() run) {
    final task = _PlaybackQueueTask<T>(run);
    _tasks.add(task);
    _drain();
    return task.future;
  }

  void _drain() {
    if (_draining) return;
    _draining = true;
    unawaited(() async {
      try {
        while (_tasks.isNotEmpty) {
          final task = _tasks.removeFirst();
          _isPlaying = true;
          try {
            task.complete(await task.run());
          } catch (error, stackTrace) {
            task.completeError(error, stackTrace);
          } finally {
            _isPlaying = false;
          }
        }
      } finally {
        _draining = false;
        if (_tasks.isNotEmpty) _drain();
      }
    }());
  }
}

class _PlaybackQueueTask<T> {
  _PlaybackQueueTask(this.run);

  final Future<T> Function() run;
  final _completer = Completer<T>();

  Future<T> get future => _completer.future;

  void complete(T value) {
    if (!_completer.isCompleted) _completer.complete(value);
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}
