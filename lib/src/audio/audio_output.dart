import 'dart:typed_data';

typedef PlaybackStartCallback = void Function();

class AudioPlayOptions {
  const AudioPlayOptions({this.onPlaybackStart});

  final PlaybackStartCallback? onPlaybackStart;
}

abstract interface class AudioPlayer {
  Future<void> play(
    Float32List samples,
    int sampleRate, {
    AudioPlayOptions options,
  });

  Future<void> stop();

  Future<void> pause();

  Future<void> resume();

  bool get isPlaying;
}

class AudioOutput {
  AudioOutput(this._player);

  final AudioPlayer? _player;
  bool _isSpeaking = false;

  Future<void> play(
    Float32List samples,
    int sampleRate, [
    AudioPlayOptions options = const AudioPlayOptions(),
  ]) async {
    final player = _player;
    if (player == null) {
      throw StateError(
        'No AudioPlayer configured. Pass a player to KittenTTS.create().',
      );
    }
    _isSpeaking = true;
    try {
      await player.play(samples, sampleRate, options: options);
    } finally {
      _isSpeaking = false;
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    _isSpeaking = false;
  }

  Future<void> pause() async {
    await _player?.pause();
    _isSpeaking = false;
  }

  Future<void> resume() async {
    await _player?.resume();
    _isSpeaking = _player?.isPlaying ?? false;
  }

  bool get isSpeaking => _player?.isPlaying ?? _isSpeaking;
}
