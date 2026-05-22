# Contributing

## Setup

```bash
flutter pub get
flutter analyze
flutter test
```

## Build And Publish Checks

```bash
flutter pub publish --dry-run
```

Run platform builds from an example app directory only when the change affects
native integration, examples, or platform-specific behavior:

```bash
cd examples/basic
flutter build ios --debug --no-codesign
flutter build apk --debug
flutter build macos --debug
flutter build web
```

Some platform builds require local SDK or device setup.

## Native Phonemizer

The checked-in native phonemizer bridge is built from `src/cephonemizer`.
Change it only when the C++ source or Dart FFI boundary needs to change.

Android, Linux, and Windows use `src/CMakeLists.txt`. iOS and macOS use the
forwarder files under `ios/Classes/` and `macos/Classes/`.

## Examples

Use the example apps to verify user-facing behavior:

```bash
cd examples/basic
flutter pub get
flutter run
```

```bash
cd examples/word_timings
flutter pub get
flutter run
```

Only run the examples needed for the change you are testing.
