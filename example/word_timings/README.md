# KittenTTS Word Timings Example

Runnable Flutter app that shows `KittenTTSResult.wordTimings`, including
word-by-word highlighting while audio plays.

## Run

From this directory:

```bash
flutter pub get
flutter run
```

The demo uses the nano-int8 model, a small voice picker, Generate, and Speak.
Speak starts a timer from `AudioPlayOptions.onPlaybackStart` and highlights the
active word by comparing elapsed playback time with each timing's `startTime`
and `endTime`.

For web, make sure `web/index.html` keeps the ONNX Runtime Web script before
Flutter bootstrap:

```html
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/ort.min.js"></script>
```
