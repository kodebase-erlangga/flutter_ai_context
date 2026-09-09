/// Redacts secret-like strings from generated output.
class Redaction {
  static final _patterns = <RegExp>[
    RegExp(
      r'(api[_-]?key|secret|token|password|auth)\s*[:=]\s*.+',
      caseSensitive: false,
    ),
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
    RegExp(r'sk-[A-Za-z0-9]{20,}'),
    RegExp(r'AIza[0-9A-Za-z\-_]{35}'),
  ];

  static String sanitize(String input) {
    var result = input;
    for (final pattern in _patterns) {
      result = result.replaceAllMapped(pattern, (match) {
        final text = match.group(0)!;
        final key = text.split(RegExp(r'[:=]')).first.trim();
        return '$key: [REDACTED]';
      });
    }
    return result;
  }
}
