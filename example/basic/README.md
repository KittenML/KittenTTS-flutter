# KittenTTS Basic Example

Runnable Flutter app with model, voice, speed, Generate, and Speak controls.

## Run

From this directory:

```bash
flutter pub get
flutter run
```

For web, make sure `web/index.html` keeps the ONNX Runtime Web script before
Flutter bootstrap:

```html
<script src="https://cdn.jsdelivr.net/npm/onnxruntime-web@1.22.0/dist/ort.min.js"></script>
```
