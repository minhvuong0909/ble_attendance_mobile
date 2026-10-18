import 'package:ble_attendance_mobile/core/api_exception.dart';
import 'package:ble_attendance_mobile/core/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requiredField rejects empty and blank values', () {
    expect(Validators.requiredField(null, 'Mã'), isNotNull);
    expect(Validators.requiredField('   ', 'Mã'), contains('Mã'));
    expect(Validators.requiredField('25CE099', 'Mã'), isNull);
  });

  test('password needs at least 6 characters', () {
    expect(Validators.password('12345'), isNotNull);
    expect(Validators.password(''), isNotNull);
    expect(Validators.password('123456'), isNull);
  });

  test('confirm must equal the other value', () {
    expect(Validators.confirm('abc123', 'abc124'), isNotNull);
    expect(Validators.confirm('abc123', 'abc123'), isNull);
    expect(Validators.confirm('', 'abc123'), isNotNull);
  });

  test('normalizeId trims and upper-cases', () {
    expect(normalizeId('  25ce099 '), '25CE099');
  });

  test('normalizeBaseUrl adds scheme and strips trailing slash', () {
    expect(normalizeBaseUrl('192.168.1.7:8000/'), 'http://192.168.1.7:8000');
    expect(
      normalizeBaseUrl('https://api.example.com'),
      'https://api.example.com',
    );
    expect(normalizeBaseUrl(' http://10.0.0.2:8000 '), 'http://10.0.0.2:8000');
  });

  test('normalizeBaseUrl rejects empty or hostless input', () {
    expect(() => normalizeBaseUrl('   '), throwsA(isA<ApiException>()));
    expect(() => normalizeBaseUrl('http://'), throwsA(isA<ApiException>()));
  });
}
