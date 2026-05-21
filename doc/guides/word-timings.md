# Word Timings

`generate()` returns `wordTimings`, which you can use for read-aloud UI,
karaoke-style highlighting, or reader apps.

```dart
final result = await tts.generate(
  'KittenTTS can return word-level timestamps.',
);

print(result.wordTimings);
```

Each timing includes the word, its index in the generated chunk, and start/end
times in seconds.

## Highlight While Playing

Generate first, then start your UI timer from `onPlaybackStart`:

```dart
final result = await tts.generate(text);

await tts.play(
  result,
  AudioPlayOptions(
    onPlaybackStart: () {
      final startedAt = DateTime.now();
      timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        final seconds =
            DateTime.now().difference(startedAt).inMilliseconds / 1000;
        final active = result.wordTimings.where(
          (word) => seconds >= word.startTime && seconds < word.endTime,
        ).firstOrNull;
        setActiveWordIndex(active?.wordIndex);
      });
    },
  ),
);
```

## Keep Chunks Short

Timings are model-predicted. They are good for UI highlighting, but they are
not a substitute for forced alignment.

For best results:

- Generate a sentence or short paragraph at a time.
- Use `stream()` for long text.
- Treat `wordIndex` as local to the generated chunk.

## Long Text

For chapters, articles, and reader apps, do not generate the whole document in
one call. Stream sentence-sized chunks and update the UI for the chunk that is
currently playing:

```dart
await for (final chunk in tts.stream(chapterText)) {
  queue.add(chunk);
  // Start playback when the first chunk is ready.
}
```
