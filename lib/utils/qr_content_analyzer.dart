class QrContentAnalysis {
  const QrContentAnalysis({
    required this.letters,
    required this.numbers,
    required this.symbols,
    required this.totalCharacters,
    required this.fingerprint,
    required this.summary,
  });

  final int letters;
  final int numbers;
  final int symbols;
  final int totalCharacters;
  final String fingerprint;
  final String summary;
}

QrContentAnalysis analyzeQrContent(String value) {
  var letters = 0;
  var numbers = 0;
  var symbols = 0;

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    if (char.contains(RegExp(r'[A-Za-z]'))) {
      letters += 1;
    } else if (char.contains(RegExp(r'[0-9]'))) {
      numbers += 1;
    } else if (char.trim().isNotEmpty) {
      symbols += 1;
    }
  }

  var hash = 0;
  for (final rune in value.runes) {
    hash = ((hash * 31) + rune) & 0x7fffffff;
  }

  final fingerprint = hash.toRadixString(16).padLeft(8, '0');
  final summary = letters > 0 && numbers > 0
      ? 'Mixed alphanumeric payload'
      : letters > 0
          ? 'Letter-based payload'
          : numbers > 0
              ? 'Numeric payload'
              : 'Symbol-based payload';

  return QrContentAnalysis(
    letters: letters,
    numbers: numbers,
    symbols: symbols,
    totalCharacters: value.length,
    fingerprint: fingerprint,
    summary: summary,
  );
}
