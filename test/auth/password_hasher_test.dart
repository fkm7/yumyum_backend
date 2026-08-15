import 'package:delmer_backend/auth/password_hasher.dart';
import 'package:test/test.dart';

void main() {
  group('hashPassword', () {
    test('is deterministic for the same input', () {
      expect(hashPassword('hunter2'), equals(hashPassword('hunter2')));
    });

    test('produces different digests for different inputs', () {
      expect(hashPassword('hunter2'), isNot(equals(hashPassword('hunter3'))));
    });

    test('never returns the plaintext', () {
      expect(hashPassword('hunter2'), isNot(contains('hunter2')));
    });

    test('produces a 64-character hex sha-256 digest', () {
      expect(hashPassword('hunter2'), matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('handles empty and unicode passwords', () {
      expect(hashPassword(''), matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(hashPassword('пароль🔐'), matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });
}
