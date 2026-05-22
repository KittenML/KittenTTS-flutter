String preprocess(String text) {
  var output = text;
  output = _expandInlineAcronyms(output);
  output = _expandCurrency(output);
  output = _expandPercentages(output);
  output = _expandOrdinals(output);
  output = _expandNumbers(output);
  output = _cleanPunctuation(output);
  output = _normaliseWhitespace(output);
  return output;
}

String _expandInlineAcronyms(String text) {
  return text.replaceAllMapped(
    RegExp(r'\b([A-Z]?[a-z]+)([A-Z]{2,})\b'),
    (match) => '${match[1]} ${match[2]!.split('').join(' ')}',
  );
}

String _expandCurrency(String text) {
  return text.replaceAllMapped(
    RegExp(r'(-)?([$€£¥])(-)?(\d+(?:[,\d]*\d)?(?:\.\d+)?)(K|M|B|T)?'),
    (match) {
      final symbol = match[2]!;
      final amountText = match[4]!;
      final multiplier = match[5];
      final cleaned = amountText.replaceAll(',', '');
      final amount = double.parse(cleaned);
      final negative = match[1] != null || match[3] != null;

      final multiplierWord = switch (multiplier) {
        'K' => ' thousand',
        'M' => ' million',
        'B' => ' billion',
        'T' => ' trillion',
        _ => '',
      };

      final currencyName = switch (symbol) {
        r'$' => amount == 1 ? ' dollar' : ' dollars',
        '€' => amount == 1 ? ' euro' : ' euros',
        '£' => amount == 1 ? ' pound' : ' pounds',
        '¥' => ' yen',
        _ => '',
      };

      final prefix = negative ? 'negative ' : '';
      if (amount == amount.floorToDouble()) {
        return '$prefix${_moneyAmountToWords(amount.floor())}'
            '$multiplierWord$currencyName';
      }

      final intPart = _moneyAmountToWords(amount.floor());
      final fracPart = cleaned.split('.').elementAtOrNull(1) ?? '';
      final fracWords = fracPart.split('').map(_digitWord).join(' ');
      return '$prefix$intPart point $fracWords$multiplierWord$currencyName';
    },
  );
}

String _moneyAmountToWords(int amount) {
  if (amount >= 1100 && amount < 2000 && amount % 100 == 0) {
    return '${numberToWords(amount ~/ 100)} hundred';
  }
  return numberToWords(amount);
}

String _expandPercentages(String text) {
  return text.replaceAllMapped(
    RegExp(r'(\d+(?:\.\d+)?)\s*%'),
    (match) {
      final numText = match[1]!;
      final value = double.parse(numText);
      if (value == value.floorToDouble()) {
        return '${numberToWords(value.floor())} percent';
      }
      final parts = numText.split('.');
      final intWords = numberToWords(value.floor());
      final fracWords =
          (parts.elementAtOrNull(1) ?? '').split('').map(_digitWord).join(' ');
      return '$intWords point $fracWords percent';
    },
  );
}

const _ordinalMap = {
  '1st': 'first',
  '2nd': 'second',
  '3rd': 'third',
  '4th': 'fourth',
  '5th': 'fifth',
  '6th': 'sixth',
  '7th': 'seventh',
  '8th': 'eighth',
  '9th': 'ninth',
  '10th': 'tenth',
  '11th': 'eleventh',
  '12th': 'twelfth',
  '13th': 'thirteenth',
  '14th': 'fourteenth',
  '15th': 'fifteenth',
  '16th': 'sixteenth',
  '17th': 'seventeenth',
  '18th': 'eighteenth',
  '19th': 'nineteenth',
  '20th': 'twentieth',
  '21st': 'twenty-first',
  '22nd': 'twenty-second',
  '23rd': 'twenty-third',
  '30th': 'thirtieth',
  '40th': 'fortieth',
  '50th': 'fiftieth',
  '100th': 'one hundredth',
  '1000th': 'one thousandth',
};

String _expandOrdinals(String text) {
  return text.replaceAllMapped(
    RegExp(r'\b(\d+)(st|nd|rd|th)\b', caseSensitive: false),
    (match) {
      final full = match[0]!.toLowerCase();
      final direct = _ordinalMap[full];
      if (direct != null) return direct;
      return ordinalToWords(int.parse(match[1]!));
    },
  );
}

String _expandNumbers(String text) {
  var output = text.replaceAllMapped(
    RegExp(r'\b(\d+)\.(\d+)\b'),
    (match) {
      final intWords = numberToWords(int.parse(match[1]!));
      final fracWords = match[2]!.split('').map(_digitWord).join(' ');
      return '$intWords point $fracWords';
    },
  );
  output = output.replaceAllMapped(
    RegExp(r'\b\d{1,3}(?:,\d{3})*\b|\b\d+\b'),
    (match) => numberToWords(int.parse(match[0]!.replaceAll(',', ''))),
  );
  return output;
}

String _cleanPunctuation(String text) {
  var output = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
  output = output.replaceAll('\u2013', '\u2014').replaceAll(' - ', ' \u2014 ');
  return output;
}

String _normaliseWhitespace(String text) =>
    text.replaceAll(RegExp(r'\s+'), ' ').trim();

const _ones = [
  '',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
  'twelve',
  'thirteen',
  'fourteen',
  'fifteen',
  'sixteen',
  'seventeen',
  'eighteen',
  'nineteen',
];

const _tens = [
  '',
  '',
  'twenty',
  'thirty',
  'forty',
  'fifty',
  'sixty',
  'seventy',
  'eighty',
  'ninety',
];

String numberToWords(int value) {
  if (value < 0) return 'negative ${numberToWords(-value)}';
  if (value == 0) return 'zero';

  var result = '';
  var remaining = value;

  for (final scale in _numberScales) {
    if (remaining >= scale.value) {
      result += '${numberToWords(remaining ~/ scale.value)} ${scale.name} ';
      remaining %= scale.value;
    }
  }

  if (remaining >= 100) {
    result += '${_ones[remaining ~/ 100]} hundred ';
    remaining %= 100;
  }
  if (remaining >= 20) {
    result += _tens[remaining ~/ 10];
    remaining %= 10;
    if (remaining > 0) result += '-${_ones[remaining]}';
  } else if (remaining > 0) {
    result += _ones[remaining];
  }

  return result.trim();
}

String ordinalToWords(int value) {
  if (value < 0) return 'negative ${ordinalToWords(-value)}';

  final direct = _ordinalWords[value];
  if (direct != null) return direct;

  if (value < 100) {
    final tens = (value ~/ 10) * 10;
    final ones = value % 10;
    if (ones == 0) return _ordinalTens[tens] ?? numberToWords(value);
    return '${_tens[tens ~/ 10]}-${ordinalToWords(ones)}';
  }

  for (final scale in _ordinalScales) {
    if (value >= scale.value) {
      final count = value ~/ scale.value;
      final remainder = value % scale.value;
      final prefix = '${numberToWords(count)} ${scale.name}';
      return remainder == 0
          ? '${prefix}th'
          : '$prefix ${ordinalToWords(remainder)}';
    }
  }

  return numberToWords(value);
}

const _ordinalWords = {
  0: 'zeroth',
  1: 'first',
  2: 'second',
  3: 'third',
  4: 'fourth',
  5: 'fifth',
  6: 'sixth',
  7: 'seventh',
  8: 'eighth',
  9: 'ninth',
  10: 'tenth',
  11: 'eleventh',
  12: 'twelfth',
  13: 'thirteenth',
  14: 'fourteenth',
  15: 'fifteenth',
  16: 'sixteenth',
  17: 'seventeenth',
  18: 'eighteenth',
  19: 'nineteenth',
};

const _ordinalTens = {
  20: 'twentieth',
  30: 'thirtieth',
  40: 'fortieth',
  50: 'fiftieth',
  60: 'sixtieth',
  70: 'seventieth',
  80: 'eightieth',
  90: 'ninetieth',
};

const _numberScales = [
  _Scale(1000000000000, 'trillion'),
  _Scale(1000000000, 'billion'),
  _Scale(1000000, 'million'),
  _Scale(1000, 'thousand'),
];

const _ordinalScales = [
  _Scale(1000000000000, 'trillion'),
  _Scale(1000000000, 'billion'),
  _Scale(1000000, 'million'),
  _Scale(1000, 'thousand'),
  _Scale(100, 'hundred'),
];

class _Scale {
  const _Scale(this.value, this.name);

  final int value;
  final String name;
}

String _digitWord(String digit) {
  return switch (digit) {
    '0' => 'zero',
    '1' => 'one',
    '2' => 'two',
    '3' => 'three',
    '4' => 'four',
    '5' => 'five',
    '6' => 'six',
    '7' => 'seven',
    '8' => 'eight',
    '9' => 'nine',
    _ => digit,
  };
}
