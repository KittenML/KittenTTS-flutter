const _pad = r'$';
const _punctuation = ';:,.!?¡¿—…"«»“” ';
const _lettersUpper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _lettersLower = 'abcdefghijklmnopqrstuvwxyz';
const _ipaSymbols =
    'ɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑʼʴʰʱʲʷˠˤ˞↓↑→↗↘’̩‘ᵻ';

const startTokenId = 0;
const endTokenId = 10;
const padTokenId = 0;

final Map<int, int> _symbolIndex = _buildSymbolIndex();

List<int> encodePhonemes(String phonemes) {
  final tokens = <int>[startTokenId];
  for (final rune in phonemes.runes) {
    final id = _symbolIndex[rune];
    if (id != null) tokens.add(id);
  }
  tokens
    ..add(endTokenId)
    ..add(padTokenId);
  return tokens;
}

Map<int, int> _buildSymbolIndex() {
  final symbols = '$_pad$_punctuation$_lettersUpper$_lettersLower$_ipaSymbols';
  final map = <int, int>{};
  var index = 0;
  for (final rune in symbols.runes) {
    map[rune] = index;
    index += 1;
  }
  return map;
}
