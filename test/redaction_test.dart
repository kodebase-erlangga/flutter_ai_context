import 'package:flutter_ai_context/src/shared/redaction.dart';
import 'package:test/test.dart';

void main() {
  test('redacts api keys from output', () {
    const input = "api_key: 'sk-abcdefghijklmnopqrstuvwxyz123456'";
    final output = Redaction.sanitize(input);
    expect(output, contains('[REDACTED]'));
    expect(output, isNot(contains('sk-abcdefghijklmnopqrstuvwxyz123456')));
  });
}
