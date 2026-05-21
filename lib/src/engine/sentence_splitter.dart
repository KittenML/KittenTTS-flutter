List<String> splitSentences(String text) {
  final sentences = <String>[];
  final buffer = StringBuffer();
  final abbreviations = {
    'dr.',
    'prof.',
    'mr.',
    'ms.',
    'mrs.',
    'jan.',
    'feb.',
    'mar.',
    'apr.',
    'jun.',
    'jul.',
    'aug.',
    'sep.',
    'sept.',
    'oct.',
    'nov.',
    'dec.',
    'fig.',
    'pp.',
  };

  for (var i = 0; i < text.length; i += 1) {
    final char = text[i];
    buffer.write(char);
    if (!'.!?'.contains(char)) continue;

    final current = buffer.toString().trim();
    final lastToken = current.split(RegExp(r'\s+')).last.toLowerCase();
    if (abbreviations.contains(lastToken)) {
      continue;
    }
    if (lastToken == 'al.' && current.toLowerCase().endsWith('et al.')) {
      continue;
    }

    if (current.isNotEmpty) sentences.add(current);
    buffer.clear();
  }

  final remaining = buffer.toString().trim();
  if (remaining.isNotEmpty) {
    if (sentences.isEmpty) {
      sentences.add(remaining);
    } else {
      sentences[sentences.length - 1] = '${sentences.last} $remaining';
    }
  }

  final merged = <String>[];
  var chunk = '';
  for (final sentence in sentences) {
    chunk = '${chunk.isEmpty ? '' : '$chunk '}$sentence';
    if (chunk.length >= 200) {
      merged.add(chunk);
      chunk = '';
    }
  }
  if (chunk.isNotEmpty) {
    if (merged.isEmpty) {
      merged.add(chunk);
    } else {
      merged[merged.length - 1] = '${merged.last} $chunk';
    }
  }
  return merged.isEmpty ? [text] : merged;
}
