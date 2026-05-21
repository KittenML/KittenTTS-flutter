# Local And Offline Assets

The default SDK path downloads model files from Hugging Face on first use and
then reuses the local cache. Apps that cannot depend on a first-run download can
ship model files themselves and point the SDK at those files.

## Required Files

Each model needs:

- The ONNX model file.
- `voices.npz`.

The default CE phonemizer also needs:

- `en_rules`.
- `en_list`.

## Use Local Model Files

Pass `modelFiles` in the config:

```dart
final tts = await KittenTTS.create(
  config: const KittenTTSConfig(
    model: 'nano-int8',
    modelFiles: KittenTTSModelFiles(
      onnxPath: '/absolute/path/to/kitten_tts_nano_v0_8.onnx',
      voicesPath: '/absolute/path/to/voices.npz',
    ),
  ),
);
```

When `modelFiles` is provided, the SDK skips model download/cache lookup and
uses those files directly.

For Flutter Web, use asset keys or HTTP(S) URLs instead of absolute filesystem
paths:

```dart
final tts = await KittenTTS.create(
  config: const KittenTTSConfig(
    modelFiles: KittenTTSModelFiles(
      onnxPath: 'assets/models/kitten_tts_nano_v0_8.onnx',
      voicesPath: 'assets/models/voices.npz',
    ),
  ),
);
```

## Use Local Phonemizer Files

Pass paths to `CEPhonemizer`:

```dart
final tts = await KittenTTS.create(
  config: KittenTTSConfig(
    phonemizer: CEPhonemizer(
      rulesPath: '/absolute/path/to/en_rules',
      listPath: '/absolute/path/to/en_list',
    ),
  ),
);
```

You can also pass `rulesText` and `listText` if your app loads the files from
Flutter assets and wants the SDK to write them into the phonemizer cache before
loading the native CE bridge.

## Custom Model Host

If you host the same filenames on your own server, set `modelBaseUrl`:

```dart
final tts = await KittenTTS.create(
  config: const KittenTTSConfig(
    model: 'nano-int8',
    modelBaseUrl: 'https://example.com/kittentts/nano-int8',
  ),
);
```

The URL must point at a directory containing the ONNX file and `voices.npz`.
On web, the server must allow browser fetches from your app origin.

## Cache Directory

Set `storageDirectory` to control where downloaded model and phonemizer files
are stored:

```dart
final tts = await KittenTTS.create(
  config: const KittenTTSConfig(
    storageDirectory: '/absolute/cache/root/KittenTTS',
  ),
);
```
