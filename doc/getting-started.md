# Getting Started

This page covers the smallest useful setup: install the SDK, create a TTS
instance, and generate speech.

## Requirements

| Requirement | Version |
| --- | --- |
| Flutter | `>= 3.22` |
| Dart | `>= 3.4` |
| iOS | `16+` |
| macOS | `14+` |
| Android | API `21+` |
| Web | ONNX Runtime Web script |

The iOS and macOS minimums follow `flutter_onnxruntime`.

## Install

```bash
flutter pub add kittentts
```

Do not install or register `flutter_onnxruntime` manually unless your app needs
to configure it directly. The SDK depends on it.

## Flutter Web

Web apps must load ONNX Runtime Web before the Flutter bootstrap script. Add
this to `web/index.html`:

```html
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/ort.min.js"></script>
<script src="flutter_bootstrap.js" async></script>
```

Then run the app normally:

```bash
flutter run -d chrome
```

On web, default model paths resolve to Hugging Face URLs and `voices.npz` is
loaded through browser fetch. `modelFiles` may point at app assets or HTTP(S)
URLs. The default `CEPhonemizer` uses the bundled JS/Emscripten CE runtime, so
phonemization follows the same C++ engine used by the native bridge and the
React Native web package.

## Generate Audio

Use `generate()` when you want audio data back without playing it immediately.

```dart
import 'package:kittentts/kittentts.dart';

final tts = await KittenTTS.create(
  onProgress: (progress, info) {
    if (info?.stage.name == 'cached') {
      print('model is already cached');
      return;
    }

    print('setup ${(progress * 100).round()}%');
  },
);

final result = await tts.generate('Hello from KittenTTS on Flutter.');

print(result.duration);
print(result.wordTimings);
print(result.wavBase64());

await tts.dispose();
```

`result.wavBase64()` returns a complete WAV file encoded as base64. You can save
it, upload it, or hand it to your own audio pipeline.

## Analytics

The SDK sends anonymous generation metadata to the KittenTTS ingest API. It
does not send input text, generated audio, or initialize an analytics-provider
SDK.
Streaming calls send one `stream` analytics event per stream invocation, not
one event per generated chunk.

```dart
final tts = await KittenTTS.create(
  config: const KittenTTSConfig(analytics: false),
);
```

## Speak Through A Player

Playback is intentionally app-provided. Implement `AudioPlayer` with the audio
package your app already uses:

```dart
class MyAudioPlayer implements AudioPlayer {
  @override
  Future<void> play(
    Float32List samples,
    int sampleRate, {
    AudioPlayOptions options = const AudioPlayOptions(),
  }) async {
    options.onPlaybackStart?.call();
    final wav = WAVEncoder.encode(samples, sampleRate);
    // Play wav bytes with your app's audio layer.
  }

  @override
  Future<void> stop() async {
    // Stop active playback.
  }

  @override
  Future<void> pause() async {
    // Pause active playback.
  }

  @override
  Future<void> resume() async {
    // Resume paused playback.
  }

  @override
  bool get isPlaying => false;
}
```

Pass it to `KittenTTS.create()`:

```dart
final tts = await KittenTTS.create(player: MyAudioPlayer());

await tts.speak('This plays through the configured audio player.');
await tts.dispose();
```

## Run The Examples

```bash
cd examples/basic
flutter run -d ios
flutter run -d chrome
```

For Android:

```bash
flutter run -d android
```

For the word timings demo:

```bash
cd examples/word_timings
flutter run -d chrome
```

If Android install fails with "not enough space", wipe the emulator data or
uninstall old test apps from the emulator.

## What Happens On First Run

On native targets, the first `KittenTTS.create()` downloads the selected model,
`voices.npz`, and phonemizer dictionary files. Later calls reuse the device
cache.

Default model cache:

```text
<ApplicationSupportDirectory>/KittenTTS/<model>/
```

Default phonemizer cache:

```text
<ApplicationSupportDirectory>/KittenTTS/CEPhonemizer/
```

To avoid a first-run model download, see [local/offline assets](guides/offline-assets.md).
