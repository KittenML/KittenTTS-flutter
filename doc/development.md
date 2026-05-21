# Development

Notes for people working on this SDK repository.

## Fresh Clone Check

```bash
flutter pub get
flutter analyze
flutter test
```

## Examples Check

```bash
cd examples/basic
flutter pub get
flutter test
flutter run -d ios
flutter run -d android

cd ../word_timings
flutter pub get
flutter test
flutter run -d chrome
```

Native builds can be slow and require local platform tooling. Run them when you
change native build files, FFI bindings, ONNX Runtime integration, or the
example apps.

## Native Phonemizer

The CE phonemizer C++ source lives in:

```text
src/cephonemizer/
```

Android, Linux, and Windows build it through:

```text
src/CMakeLists.txt
```

iOS and macOS build it through CocoaPods using forwarder files:

```text
ios/Classes/kittentts_cephonemizer.cpp
macos/Classes/kittentts_cephonemizer.cpp
```

Those forwarder files include the shared C++ source. This matches Flutter's FFI
plugin pattern and avoids CocoaPods issues with source files outside the pod
directory.

Flutter Web uses a generated JavaScript/Emscripten CE runtime built from the
same C++ source:

```text
web/kittentts_cephonemizer.js
```

Regenerate it with Emscripten from the repository root:

```bash
emcc src/cephonemizer/phonemizer.cpp src/cephonemizer/swift_bridge.cpp \
  -O3 -std=c++17 -fexceptions \
  -sWASM=0 \
  -sMODULARIZE=1 \
  -sEXPORT_NAME=createKittenTtsCePhonemizerModule \
  -sENVIRONMENT=web,worker,shell \
  -sFILESYSTEM=1 \
  -sALLOW_MEMORY_GROWTH=1 \
  -sDISABLE_EXCEPTION_CATCHING=0 \
  "-sEXPORTED_FUNCTIONS=['_phonemizer_create','_phonemizer_destroy','_phonemizer_phonemize','_phonemizer_free_string']" \
  "-sEXPORTED_RUNTIME_METHODS=['cwrap','UTF8ToString','FS']" \
  -o web/kittentts_cephonemizer.js
```

## Packaging

Check the package before publishing:

```bash
flutter pub publish --dry-run
```

The dry run should include the native C++ source, platform build files, docs,
README, changelog, and Apache 2.0 license.

## Documentation

When changing the public API, update:

```text
README.md
doc/reference/api.md
doc/getting-started.md
```

When changing platform requirements or native build behavior, update:

```text
doc/troubleshooting.md
doc/development.md
AGENTS.md
```

## Generated Files

Do not commit Flutter build outputs:

```text
build/
examples/*/build/
.dart_tool/
examples/*/.dart_tool/
```

Use `dart format` for Dart changes and keep edits focused on source files.
