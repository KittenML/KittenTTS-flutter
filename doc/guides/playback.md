# Playback

KittenTTS separates generation from playback. That keeps the SDK usable in apps
that want to save audio data, stream chunks, use a custom player, or sync UI state
with the audio.

## Generate Without Playing

```dart
final result = await tts.generate('Save this as audio.');

final wavBytes = result.wavData();
final wavBase64 = result.wavBase64();
```

Use this when your app uploads audio, stores files, or has its own playback
stack.

## Use `speak()`

Pass a player to `KittenTTS.create()`, then call `speak()`:

```dart
await tts.speak(
  'Read this sentence.',
  voice: 'bella',
  speed: 1.0,
);
```

The optional speed value is clamped from `0.5` to `2.0`.

## Custom Player

Implement `AudioPlayer` if your app already has an audio layer:

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
    // Play the WAV bytes.
  }

  @override
  Future<void> stop() async {
    // Stop active playback.
  }
}
```

Then pass it to the SDK:

```dart
final tts = await KittenTTS.create(player: MyAudioPlayer());
```

## Generate First, Then Play

This is useful when the UI needs metadata from the generated result before
audio starts.

```dart
final result = await tts.generate('Highlight this sentence.');

await tts.play(
  result,
  AudioPlayOptions(
    onPlaybackStart: () {
      startHighlighting(result.wordTimings);
    },
  ),
);
```

`onPlaybackStart` should fire when audio is actually playing, not when the file
only starts loading. That detail matters for word highlighting.

## Queue Playback

```dart
final queue = tts.createPlaybackQueue();

queue.enqueue(firstResult);
queue.enqueue(secondResult);
queue.enqueueText('Generate this when the previous clips finish.');
```

The queue plays one item at a time. `enqueueText()` waits to generate until the
item reaches the front, so playback order stays stable for short and long input.
`queue.clear()` removes pending items, and `await queue.stop()` clears pending
items and stops active playback.

For strict sequencing, custom `AudioPlayer.play()` implementations should
resolve after playback finishes.

## Example Playback

The example apps use `audioplayers` outside the SDK package. They encode samples
to WAV and passes the bytes to `audioplayers` with the `audio/wav` MIME type.

Playback remains optional in the SDK itself so apps can use `audioplayers`,
`just_audio`, platform channels, or any other audio layer.
