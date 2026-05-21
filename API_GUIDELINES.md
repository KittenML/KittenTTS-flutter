# KittenTTS Flutter API Guidelines

Use the same public shape as the other SDKs: string IDs plus config and named options.

```dart
final config = KittenTTSConfig(
  model: 'mini',
  defaultVoice: 'luna',
  speed: 1.1,
);

final tts = await KittenTTS.create(config: config, player: myAudioPlayer);

final result = await tts.generate(
  'Hello',
  voice: 'luna',
  speed: 1.1,
);

await tts.play(result);
await tts.speak('Hello', voice: 'bella', speed: 1.0);
await tts.speak(
  'Hello',
  voice: 'bella',
  speed: 1.0,
  options: AudioPlayOptions(onPlaybackStart: onPlaybackStart),
);

await for (final chunk in tts.stream(longText, voice: 'luna')) {
  await tts.play(chunk);
}

final cache = await KittenTTS.cacheInfo(config);
await KittenTTS.predownload(config);
await KittenTTS.validateAssets(config);
```

Public IDs:

```dart
typedef KittenTTSModelId = String; // 'nano', 'nano-int8', 'micro', 'mini'
typedef KittenTTSVoiceId = String; // 'bella', 'jasper', 'luna', 'bruno', 'rosie', 'hugo', 'kiki', 'leo'
```

Dart does not have TypeScript-style string literal unions, so the SDK validates IDs at config and generation boundaries.
