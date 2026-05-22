# API Reference

This page lists the main public APIs. The Dart types in the package are the
source of truth.

## `KittenTTS.create({ config, onProgress, player, forceRedownload })`

Creates and initializes a TTS instance. It resolves config, prepares the
phonemizer, loads or downloads model assets, reads `voices.npz`, and creates the
ONNX Runtime session.

```dart
final tts = await KittenTTS.create(
  config: const KittenTTSConfig(
    model: 'nano-int8',
    defaultVoice: 'luna',
    speed: 1.1,
  ),
  player: myAudioPlayer,
);
```

The progress callback receives a number from `0` to `1`. The optional second
argument describes the current stage:

```dart
final tts = await KittenTTS.create(
  onProgress: (progress, info) {
    if (info?.stage.name == 'cached') {
      print('model is already downloaded');
    }

    print((progress * 100).round());
  },
);
```

## Common Options

| Option | Default | Description |
| --- | --- | --- |
| `model` | `"nano"` | Model variant |
| `defaultVoice` | `"bella"` | Voice used when omitted |
| `speed` | `1.0` | Speech speed from `0.5` to `2.0` |
| `storageDirectory` | Application support directory, or `"KittenTTS"` on web | Custom model cache root |
| `modelBaseUrl` | Hugging Face URL | Custom mirror/self-hosted model directory |
| `modelFiles` | none | Local native paths, web asset keys, or HTTP(S) URLs for ONNX and `voices.npz` |
| `downloadRetries` | `4` | Total download attempts per model file |
| `ortNumThreads` | `4` | ONNX Runtime thread count |
| `maxTokensPerChunk` | `400` | Long-text chunk size |
| `trimTrailingSilence` | `true` | Trim near-silent audio at chunk ends |
| `silenceThreshold` | `0.005` | Amplitude threshold for silence trimming |
| `maxSilenceTrimMs` | `250` | Maximum trailing silence removed per chunk |
| `phonemizer` | `CEPhonemizer` | Custom text-to-IPA converter |
| `analytics` | `true` | Set to `false` to disable anonymous generation analytics |
| `forceRedownload` | `false` | Redownload model files before creating |
| `player` | none | Required for `speak()` and `play()` |

Analytics events go to the KittenTTS ingest API and do not include input text or
generated audio.

Generation analytics use `wav` for `generate()`, `speak` for `speak()`, and
`stream` for `stream()`. Streaming sends one event per stream invocation, not
one event per generated chunk.

## `tts.generate(text, { voice, speed })`

Synthesizes speech and returns a `KittenTTSResult` without playing it.

```dart
final result = await tts.generate(
  'Save this as audio.',
  voice: 'jasper',
);
```

`wordTimings` may be empty when duration output is unavailable or when the text
is split across multiple model chunks.

## `tts.stream(text, { voice, speed })`

Synthesizes long text sentence by sentence.

```dart
await for (final chunk in tts.stream(
  longText,
  voice: 'luna',
)) {
  await tts.play(chunk);
}
```

## `tts.speak(text, { voice, speed, options })`

Synthesizes speech and plays it through the configured player.

```dart
await tts.speak(
  'Play this sentence.',
  voice: 'rosie',
  speed: 1.1,
  options: AudioPlayOptions(
    onPlaybackStart: handlePlaybackStarted,
  ),
);
```

## `tts.play(result, [options])`

Plays a previously generated result.

```dart
final result = await tts.generate('Highlight words while this plays.');

await tts.play(
  result,
  AudioPlayOptions(
    onPlaybackStart: () => startWordHighlighting(result.wordTimings),
  ),
);
```

## `tts.createPlaybackQueue()`

```dart
final queue = tts.createPlaybackQueue();

await queue.enqueue(result);
await queue.enqueueText('Play this after earlier queued audio.', voice: 'luna');
```

Returns a FIFO `PlaybackQueue` for serial playback. `enqueue(result)` queues an
existing `KittenTTSResult`. `enqueueText(text, ...)` queues generation and
playback together, and generation starts when that item reaches the front of the
queue. Use `queue.clear()` to reject pending items or `await queue.stop()` to
clear pending items and stop active playback.

## `KittenTTSResult`

| Property or method | Description |
| --- | --- |
| `samples` | Raw mono `Float32List` PCM |
| `sampleRate` | Always `24000` |
| `duration` | Audio duration in seconds |
| `voice` | Voice used for generation |
| `effectiveSpeed` | Speed after model-specific adjustments |
| `inputText` | Input text that was synthesized |
| `wordTimings` | Per-word `{ wordIndex, word, startTime, endTime }` list |
| `wavData()` | Complete 16-bit PCM WAV as `Uint8List` |
| `wavBase64()` | Complete WAV as a base64 string |
| `mp3Data({ bitRate })` | Throws `UnsupportedError` until a small non-GPL Flutter MP3 encoder is available |
| `mp3Base64({ bitRate })` | Throws `UnsupportedError` until a small non-GPL Flutter MP3 encoder is available |

MP3 helpers remain API-compatible, but currently throw instead of bundling
GPL/LGPL codec packages.

## Cache Methods

| Method | Description |
| --- | --- |
| `KittenTTS.cacheInfo(config)` | Returns cache paths and file existence; web returns URL paths unless `modelFiles` is supplied |
| `KittenTTS.predownload(config, onProgress: ...)` | Downloads native model and phonemizer assets; web resolves URL/asset paths |
| `KittenTTS.validateAssets(config)` | Throws if required assets are missing |
| `KittenTTS.redownloadModel(config, onProgress: ...)` | Deletes and downloads the selected model |
| `KittenTTS.clearModelCache(config)` | Deletes cached files for the selected model |

## Audio Player

`speak()` and `play()` require an `AudioPlayer`.

```dart
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
```

## Phonemizer

The default `CEPhonemizer` uses the native CE C++ bridge on Flutter native
targets.

```dart
final tts = await KittenTTS.create(
  config: KittenTTSConfig(
    phonemizer: CEPhonemizer(
      dialect: 'en-us',
      allowRuleBasedFallback: true,
    ),
  ),
);
```

You can provide a custom implementation of `KittenPhonemizerProtocol` for web,
testing, or app-specific text-to-IPA behavior. The default web path uses the
bundled JS/Emscripten CE runtime because the native CE FFI bridge is unavailable
in browsers.

## Errors

SDK errors are surfaced as `KittenTTSError` when possible.

```dart
try {
  await tts.speak('Hello.');
} catch (error) {
  if (error is KittenTTSError) {
    print(error.code);
    print(error.message);
  }
}
```

| Code | Meaning |
| --- | --- |
| `emptyInput` | Text was empty |
| `downloadFailed` | Model or phonemizer download failed |
| `invalidModelData` | Cached model data could not be parsed |
| `phonemizerFailed` | Text-to-phoneme conversion failed |
| `inferenceFailed` | ONNX Runtime setup or inference failed |
| `playbackFailed` | Audio playback failed |
