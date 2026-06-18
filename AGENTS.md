# AGENTS.md

Guidance for coding agents working on `kittentts`.

## Project Overview

This package is a Flutter SDK for on-device KittenTTS speech synthesis.
The public API downloads and caches model assets, prepares the native CE
phonemizer, runs ONNX Runtime on-device through `flutter_onnxruntime`, and
optionally plays generated WAV audio through a user-provided `AudioPlayer`.

Main flow:

1. `KittenTTS.create()` resolves config, prepares the phonemizer, downloads any
   missing model files, loads `voices.npz`, and creates the ONNX engine.
2. `tts.generate()` preprocesses text, phonemizes it, tokenizes IPA symbols,
   runs ONNX inference, and returns `KittenTTSResult`.
3. `tts.speak()` calls `generate()` and sends the result to an `AudioPlayer`.

## Important Paths

- `lib/kittentts.dart`: public exports.
- `lib/src/kitten_tts.dart`: main SDK class and lifecycle.
- `lib/src/kitten_tts_config.dart`: user config and defaults.
- `lib/src/kitten_tts_error.dart`: SDK error codes and helpers.
- `lib/src/kitten_model.dart`: model names, download URLs, sizes, speed priors.
- `lib/src/kitten_voice.dart`: voice enum and display helpers.
- `lib/src/loader/model_downloader.dart`: model cache and Hugging Face downloads.
- `lib/src/loader/npz_loader.dart`: `voices.npz` ZIP/NPY parsing.
- `lib/src/engine/tts_engine.dart`: text-to-token-to-ONNX inference.
- `lib/src/engine/text_preprocessor.dart`: RN-compatible text preprocessing.
- `lib/src/phonemizer/ce_phonemizer.dart`: Dart CE phonemizer wrapper.
- `lib/src/phonemizer/native/`: FFI bindings for the native CE bridge.
- `lib/src/audio/audio_output.dart`: optional playback interfaces.
- `src/cephonemizer/`: vendored C++ phonemizer source.
- `src/CMakeLists.txt`: native CMake build for Android, Linux, and Windows.
- `ios/` and `macos/`: CocoaPods FFI plugin build files.
- `examples/basic/`: Flutter example app similar to the RN Expo example.
- `examples/word_timings/`: Flutter word timing and highlighting example.

## Build And Validation

Use these from the repository root:

```bash
flutter analyze
flutter test
flutter pub publish --dry-run
```

Use these from each example directory when changing examples or native
integration:

```bash
flutter test
flutter build ios --debug --no-codesign
flutter build apk --debug
flutter build macos --debug
flutter build web
```

Only run platform builds when needed. They can be slow and may require local
SDK/device setup.

## Dependency Notes

- Runtime dependencies include `flutter_onnxruntime`, `path_provider`, `http`,
  `archive`, `path`, and `ffi`.
- Playback is optional. Users must pass an `AudioPlayer` implementation to
  `KittenTTS.create()` for `speak()` and `play()`.
- The examples use `audioplayers` only as app-side playback implementations.
  Do not move `audioplayers` into the SDK package unless the public playback
  contract changes.
- iOS and macOS minimum versions follow `flutter_onnxruntime` requirements in
  this package: iOS 16 and macOS 14.

## Native Phonemizer

The default `CEPhonemizer` uses the vendored C++ source through Dart FFI on
Android, iOS, macOS, Linux, and Windows.

Android, Linux, and Windows use `src/CMakeLists.txt`. iOS and macOS use
small forwarder source files in `ios/Classes/` and `macos/Classes/` because
CocoaPods does not reliably compile source files outside the pod directory.

Keep the exported bridge functions in `src/cephonemizer/swift_bridge.cpp`
stable because Dart FFI looks them up by symbol name.

## Model Cache Behavior

Model files are cached under:

```text
<ApplicationSupportDirectory>/KittenTTS/<model>/
```

unless `storageDirectory` is provided. Downloads should only treat completed
files as valid cache entries. Keep cache behavior conservative because first-run
downloads are large.

The default `CEPhonemizer` also caches dictionary files under:

```text
<ApplicationSupportDirectory>/KittenTTS/CEPhonemizer/
```

## Error Handling

Public SDK failures should be surfaced as `KittenTTSError` with a stable
`KittenTTSErrorCode` whenever practical. Preserve underlying errors in `cause`
when wrapping them.

Avoid leaking raw native, filesystem, parser, or playback errors from public
entry points unless there is no reasonable SDK boundary around that code.

## Editing Rules

- Keep public API changes small and documented in `README.md` and `doc/reference/api.md`.
- Prefer adding focused tests or at least running `flutter analyze` for SDK changes.
- Keep generated Flutter build output untouched.
- Preserve the package's Dart-first API and avoid app-side setup that breaks
  Flutter plugin autolinking.
- Keep Flutter API behavior close to `@kittentts/react-native` unless a Dart
  convention clearly improves the developer experience.
- Do not remove Apple linker settings for the native phonemizer without checking
  that Dart FFI can still resolve `phonemizer_create` in a built app.
