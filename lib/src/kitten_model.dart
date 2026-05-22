import 'kitten_voice.dart';

typedef KittenTTSModelId = String;

const model = _KittenTTSModels();

const allKittenTTSModelIds = <KittenTTSModelId>[
  'nano',
  'nano-int8',
  'micro',
  'mini',
];

class _KittenTTSModels {
  const _KittenTTSModels();

  final KittenTTSModelId nano = 'nano';
  final KittenTTSModelId nanoInt8 = 'nano-int8';
  final KittenTTSModelId micro = 'micro';
  final KittenTTSModelId mini = 'mini';
}

KittenTTSModelId validateModel(KittenTTSModelId model) {
  if (allKittenTTSModelIds.contains(model)) return model;
  throw ArgumentError.value(model, 'model', 'Unknown KittenTTS model ID.');
}

String modelRepoId(KittenTTSModelId model) {
  switch (validateModel(model)) {
    case 'nano':
      return 'kitten-tts-nano-0.8';
    case 'nano-int8':
      return 'kitten-tts-nano-0.8-int8';
    case 'micro':
      return 'kitten-tts-micro-0.8';
    case 'mini':
      return 'kitten-tts-mini-0.8';
  }
  throw StateError('Unreachable model ID: $model');
}

String huggingFaceRepo(KittenTTSModelId model) => 'KittenML/${modelRepoId(model)}';

String huggingFaceBaseUrl(KittenTTSModelId model) =>
    'https://huggingface.co/${huggingFaceRepo(model)}/resolve/main';

String onnxFileName(KittenTTSModelId model) {
  switch (validateModel(model)) {
    case 'nano':
    case 'nano-int8':
      return 'kitten_tts_nano_v0_8.onnx';
    case 'micro':
      return 'kitten_tts_micro_v0_8.onnx';
    case 'mini':
      return 'kitten_tts_mini_v0_8.onnx';
  }
  throw StateError('Unreachable model ID: $model');
}

String voicesFileName(KittenTTSModelId model) {
  validateModel(model);
  return 'voices.npz';
}

int approximateDownloadBytes(KittenTTSModelId model) {
  switch (validateModel(model)) {
    case 'nano':
      return 56000000;
    case 'nano-int8':
      return 25000000;
    case 'micro':
      return 41000000;
    case 'mini':
      return 80000000;
  }
  throw StateError('Unreachable model ID: $model');
}

double speedPrior(KittenTTSModelId model, KittenTTSVoiceId voice) {
  switch (validateModel(model)) {
    case 'nano':
    case 'nano-int8':
      return validateVoice(voice) == 'hugo' ? 0.9 : 0.8;
    case 'micro':
    case 'mini':
      return 1.0;
  }
  throw StateError('Unreachable model ID: $model');
}

String modelDisplayName(KittenTTSModelId model) {
  switch (validateModel(model)) {
    case 'nano':
      return 'Nano (fp32)';
    case 'nano-int8':
      return 'Nano (int8)';
    case 'micro':
      return 'Micro';
    case 'mini':
      return 'Mini';
  }
  throw StateError('Unreachable model ID: $model');
}
