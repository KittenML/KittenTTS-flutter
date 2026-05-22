typedef KittenTTSVoiceId = String;

const voice = _KittenTTSVoices();

const allKittenTTSVoiceIds = <KittenTTSVoiceId>[
  'bella',
  'jasper',
  'luna',
  'bruno',
  'rosie',
  'hugo',
  'kiki',
  'leo',
];

class _KittenTTSVoices {
  const _KittenTTSVoices();

  final KittenTTSVoiceId bella = 'bella';
  final KittenTTSVoiceId jasper = 'jasper';
  final KittenTTSVoiceId luna = 'luna';
  final KittenTTSVoiceId bruno = 'bruno';
  final KittenTTSVoiceId rosie = 'rosie';
  final KittenTTSVoiceId hugo = 'hugo';
  final KittenTTSVoiceId kiki = 'kiki';
  final KittenTTSVoiceId leo = 'leo';
}

KittenTTSVoiceId validateVoice(KittenTTSVoiceId voice) {
  if (allKittenTTSVoiceIds.contains(voice)) return voice;
  throw ArgumentError.value(voice, 'voice', 'Unknown KittenTTS voice ID.');
}

String voiceEmbeddingKey(KittenTTSVoiceId voice) {
  switch (validateVoice(voice)) {
    case 'bella':
      return 'expr-voice-2-f';
    case 'jasper':
      return 'expr-voice-2-m';
    case 'luna':
      return 'expr-voice-3-f';
    case 'bruno':
      return 'expr-voice-3-m';
    case 'rosie':
      return 'expr-voice-4-f';
    case 'hugo':
      return 'expr-voice-4-m';
    case 'kiki':
      return 'expr-voice-5-f';
    case 'leo':
      return 'expr-voice-5-m';
  }
  throw StateError('Unreachable voice ID: $voice');
}

String voiceDisplayName(KittenTTSVoiceId voice) {
  switch (validateVoice(voice)) {
    case 'bella':
      return 'Bella';
    case 'jasper':
      return 'Jasper';
    case 'luna':
      return 'Luna';
    case 'bruno':
      return 'Bruno';
    case 'rosie':
      return 'Rosie';
    case 'hugo':
      return 'Hugo';
    case 'kiki':
      return 'Kiki';
    case 'leo':
      return 'Leo';
  }
  throw StateError('Unreachable voice ID: $voice');
}

bool isFemaleVoice(KittenTTSVoiceId voice) =>
    voice == 'bella' || voice == 'luna' || voice == 'rosie' || voice == 'kiki';
