# Models And Voices

KittenTTS ships several model sizes. Pick the smallest model that sounds good
enough for your use case.

## Models

Start with `nano-int8` when app size and download size matter. Use `mini` when
quality is more important.

| Model | ID | Parameters | Approx download | Hugging Face |
| --- | --- | --- | --- | --- |
| Nano int8 | `"nano-int8"` | 15M | 25 MB | [kitten-tts-nano-0.8-int8](https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8) |
| Nano fp32 | `"nano"` | 15M | 56 MB | [kitten-tts-nano-0.8](https://huggingface.co/KittenML/kitten-tts-nano-0.8) |
| Micro | `"micro"` | 40M | 41 MB | [kitten-tts-micro-0.8](https://huggingface.co/KittenML/kitten-tts-micro-0.8) |
| Mini | `"mini"` | 80M | 80 MB | [kitten-tts-mini-0.8](https://huggingface.co/KittenML/kitten-tts-mini-0.8) |

```dart
final tts = await KittenTTS.create(
  config: const KittenTTSConfig(model: 'nano-int8'),
);
```

## Voices

| Voice | ID | Character |
| --- | --- | --- |
| Bella | `"bella"` | Warm and expressive |
| Jasper | `"jasper"` | Clear and conversational |
| Luna | `"luna"` | Calm and smooth |
| Bruno | `"bruno"` | Deep and steady |
| Rosie | `"rosie"` | Bright and friendly |
| Hugo | `"hugo"` | Authoritative |
| Kiki | `"kiki"` | Lively and energetic |
| Leo | `"leo"` | Relaxed and natural |

```dart
await tts.speak('Luna speaking.', voice: 'luna');
await tts.speak('Slower Bella speaking.', voice: 'bella', speed: 0.8);
```
