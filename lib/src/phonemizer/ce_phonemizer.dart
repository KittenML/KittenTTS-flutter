import '../kitten_tts_error.dart';
import 'ce_phonemizer_dictionary.dart';
import 'native/ce_phonemizer_native_stub.dart'
    if (dart.library.io) 'native/ce_phonemizer_native_io.dart'
    if (dart.library.js_interop) 'native/ce_phonemizer_native_web.dart';
import 'phonemizer_protocol.dart';

class CEPhonemizer implements KittenPhonemizerProtocol {
  CEPhonemizer({
    this.rulesUrl = defaultRulesUrl,
    this.listUrl = defaultListUrl,
    this.rulesPath,
    this.listPath,
    this.rulesText,
    this.listText,
    this.dialect = 'en-us',
    this.backend,
    this.allowRuleBasedFallback = false,
  }) : _native = NativeCEPhonemizerBackend(dialect: dialect);

  static const defaultRulesUrl =
      'https://raw.githubusercontent.com/espeak-ng/espeak-ng/59eb19938f12e30881c81d86ce4a7de25414c9f4/dictsource/en_rules';
  static const defaultListUrl =
      'https://raw.githubusercontent.com/espeak-ng/espeak-ng/59eb19938f12e30881c81d86ce4a7de25414c9f4/dictsource/en_list';

  final String rulesUrl;
  final String listUrl;
  final String? rulesPath;
  final String? listPath;
  final String? rulesText;
  final String? listText;
  final String dialect;

  final KittenPhonemizerProtocol? backend;
  final bool allowRuleBasedFallback;
  final NativeCEPhonemizerBackend _native;
  final _fallback = RuleBasedPhonemizer();
  var _loadedFallback = false;

  @override
  Future<void> downloadIfNeeded(
    String storageDirectory, {
    void Function(double progress)? onProgress,
  }) async {
    final delegate = backend;
    if (delegate != null) {
      await delegate.downloadIfNeeded(storageDirectory, onProgress: onProgress);
      return;
    }

    try {
      final paths = await _resolveDictionaryPaths(storageDirectory, onProgress);
      await _native.load(rulesPath: paths.rulesPath, listPath: paths.listPath);
      onProgress?.call(1);
    } catch (error) {
      if (!allowRuleBasedFallback) {
        if (error is KittenTTSError) rethrow;
        throw KittenTTSError.phonemizerFailed(errorMessage(error), error);
      }
      _loadedFallback = true;
      onProgress?.call(1);
    }
  }

  @override
  Future<String> phonemize(String text) async {
    final delegate = backend;
    if (delegate != null) return delegate.phonemize(text);
    if (_loadedFallback) return _fallback.phonemize(text);
    return _native.phonemize(text);
  }

  @override
  Future<void> dispose() async {
    await backend?.dispose();
    await _native.dispose();
    await _fallback.dispose();
  }

  Future<_DictionaryPaths> _resolveDictionaryPaths(
    String storageDirectory,
    void Function(double progress)? onProgress,
  ) async {
    final paths = await resolveDictionaryPaths(
      storageDirectory: storageDirectory,
      rulesUrl: rulesUrl,
      listUrl: listUrl,
      rulesPath: rulesPath,
      listPath: listPath,
      rulesText: rulesText,
      listText: listText,
      onProgress: onProgress,
    );
    return _DictionaryPaths(paths.rulesPath, paths.listPath);
  }
}

class RuleBasedPhonemizer implements KittenPhonemizerProtocol {
  @override
  Future<void> downloadIfNeeded(
    String storageDirectory, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1);
  }

  @override
  Future<String> phonemize(String text) async {
    final tokens = RegExp(r"[a-zA-Z']+|[;:,.!?—…]")
        .allMatches(text)
        .map((match) => match.group(0)!)
        .expand(_splitCamelCase)
        .map(_phonemizeToken)
        .where((token) => token.isNotEmpty)
        .toList();
    return tokens.join(' ');
  }

  @override
  Future<void> dispose() async {}
}

List<String> _splitCamelCase(String word) {
  if (word.length <= 1) return [word];
  final hasLower = RegExp(r'[a-z]').hasMatch(word);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(word);
  if (!hasLower || !hasUpper) return [word];
  return word
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(
          RegExp(r'([A-Z]+)([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}')
      .split(' ');
}

String _phonemizeToken(String token) {
  if (RegExp(r'^[;:,.!?—…]$').hasMatch(token)) return token;
  final lower = token.toLowerCase();
  final direct = _lexicon[lower];
  if (direct != null) return direct;
  if (lower.length == 1) return _letterNames[lower] ?? lower;
  if (RegExp(r'^[a-z]+$').hasMatch(lower)) return _ruleG2P(lower);
  return '';
}

String _ruleG2P(String word) {
  var result = '';
  var i = 0;
  while (i < word.length) {
    final rem = word.substring(i);
    if (rem.startsWith('tion')) {
      result += 'ʃən';
      i += 4;
      continue;
    }
    if (rem.startsWith('sh')) {
      result += 'ʃ';
      i += 2;
      continue;
    }
    if (rem.startsWith('ch')) {
      result += 'ʧ';
      i += 2;
      continue;
    }
    if (rem.startsWith('th')) {
      result += 'θ';
      i += 2;
      continue;
    }
    if (rem.startsWith('ph')) {
      result += 'f';
      i += 2;
      continue;
    }
    if (rem.startsWith('ng')) {
      result += 'ŋ';
      i += 2;
      continue;
    }
    if (rem.startsWith('oo')) {
      result += 'uː';
      i += 2;
      continue;
    }
    if (rem.startsWith('ee') || rem.startsWith('ea')) {
      result += 'iː';
      i += 2;
      continue;
    }
    final char = word[i];
    result += _letterSounds[char] ?? char;
    i += 1;
  }
  return result;
}

const _letterSounds = {
  'a': 'æ',
  'b': 'b',
  'c': 'k',
  'd': 'd',
  'e': 'ɛ',
  'f': 'f',
  'g': 'ɡ',
  'h': 'h',
  'i': 'ɪ',
  'j': 'ʤ',
  'k': 'k',
  'l': 'l',
  'm': 'm',
  'n': 'n',
  'o': 'ɑ',
  'p': 'p',
  'q': 'k',
  'r': 'ɹ',
  's': 's',
  't': 't',
  'u': 'ʌ',
  'v': 'v',
  'w': 'w',
  'x': 'ks',
  'y': 'j',
  'z': 'z',
};

const _letterNames = {
  'a': 'eɪ',
  'b': 'biː',
  'c': 'siː',
  'd': 'diː',
  'e': 'iː',
  'f': 'ɛf',
  'g': 'ʤiː',
  'h': 'eɪʧ',
  'i': 'aɪ',
  'j': 'ʤeɪ',
  'k': 'keɪ',
  'l': 'ɛl',
  'm': 'ɛm',
  'n': 'ɛn',
  'o': 'oʊ',
  'p': 'piː',
  'q': 'kjuː',
  'r': 'ɑɹ',
  's': 'ɛs',
  't': 'tiː',
  'u': 'juː',
  'v': 'viː',
  'w': 'dʌbəljuː',
  'x': 'ɛks',
  'y': 'waɪ',
  'z': 'ziː',
};

const _lexicon = {
  'a': 'ə',
  'and': 'ænd',
  'at': 'æt',
  'audio': 'ˈɔːdioʊ',
  'bella': 'ˈbɛlə',
  'bruno': 'ˈbrunoʊ',
  'can': 'kæn',
  'doctor': 'ˈdɑktɚ',
  'dollars': 'ˈdɑlɚz',
  'flutter': 'ˈflʌtɚ',
  'from': 'fɹʌm',
  'hello': 'həˈloʊ',
  'is': 'ɪz',
  'kitten': 'ˈkɪtən',
  'kittentts': 'ˈkɪtən ti ti ɛs',
  'on': 'ɑn',
  'one': 'wʌn',
  'point': 'pɔɪnt',
  'result': 'ɹɪˈzʌlt',
  'speak': 'spiːk',
  'speech': 'spiːʧ',
  'text': 'tɛkst',
  'the': 'ðə',
  'this': 'ðɪs',
  'three': 'θɹiː',
  'to': 'tuː',
  'two': 'tuː',
  'voice': 'vɔɪs',
  'world': 'wɝːld',
  'zero': 'ˈzɪɹoʊ',
};

class _DictionaryPaths {
  const _DictionaryPaths(this.rulesPath, this.listPath);

  final String rulesPath;
  final String listPath;
}
