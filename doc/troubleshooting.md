# Troubleshooting

## `speak()` Says No Audio Player Is Configured

Pass a player to `KittenTTS.create()`:

```dart
final tts = await KittenTTS.create(player: myAudioPlayer);
```

If you do not need playback, use `generate()` instead.

## iOS Playback Fails With AVPlayerItem.Status.failed

This usually means the app-side audio player did not identify the generated WAV
bytes correctly. The example apps use `audioplayers` and pass the MIME type:

```dart
await player.play(BytesSource(wav, mimeType: 'audio/wav'));
```

If your player writes bytes to a temporary file, use a `.wav` extension and a
WAV MIME type where the package supports it.

## Android Install Fails With Not Enough Space

The emulator is out of internal storage. Uninstall the existing app or wipe the
emulator data:

```bash
adb uninstall com.example.example
flutter run -d android
```

If that is not enough, wipe the AVD from Android Studio Device Manager.

## First Run Is Slow

The selected model and phonemizer files download on first use. Later native
runs use the local cache. Web builds load model files through browser fetch and
ONNX Runtime Web, so browser HTTP caching depends on the hosting server and
browser cache policy.

Check the cache before showing setup UI:

```dart
final cache = await KittenTTS.cacheInfo(
  const KittenTTSConfig(model: 'nano-int8'),
);

print(cache.isCached);
```

## Downloads Fail Or Restart

Downloads are written to temporary `.download` files first. A partial failed
download is not treated as a valid model.

The SDK retries each model file 4 times by default. If setup was interrupted,
force a clean redownload:

```dart
await KittenTTS.redownloadModel(
  const KittenTTSConfig(model: 'nano-int8'),
  onProgress: setProgress,
);
```

## ONNX Runtime Issues

This package uses `flutter_onnxruntime`. Make sure your app meets that package's
platform requirements. In this SDK, the examples use iOS 16 and macOS 14 minimum
deployment targets.

For web, load ONNX Runtime Web before Flutter starts:

```html
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/ort.min.js"></script>
<script src="flutter_bootstrap.js" async></script>
```

If iOS or macOS pods do not pick up native changes, run:

```bash
cd examples/basic/ios && pod install
cd ../macos && pod install
```

Then rebuild the app.

## Web Phonemizer

Flutter web builds can run inference through `flutter_onnxruntime`, but Dart FFI
cannot load the native CE C++ bridge in a browser. The default `CEPhonemizer`
therefore uses the bundled JS/Emscripten CE runtime built from the vendored C++
source.

If you need a temporary no-download phonemizer for experiments, opt into the
Dart rule-based fallback explicitly:

```dart
CEPhonemizer(allowRuleBasedFallback: true)
```

The fallback is not quality-equivalent to CE and should not be used for normal
speech output.

## Local Model Files Are Missing

When using `modelFiles`, both paths must exist:

```dart
const KittenTTSModelFiles(
  onnxPath: '/absolute/path/to/model.onnx',
  voicesPath: '/absolute/path/to/voices.npz',
)
```

The SDK skips downloads in this mode and fails fast if either file is missing.
