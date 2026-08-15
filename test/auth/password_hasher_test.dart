import 'package:delmer_backend/auth/bcrypt_password_hasher.dart';
import 'package:test/test.dart';

void main() {
  // Cost 4 is the bcrypt minimum. Production uses 12; the cost is a
  // constructor argument precisely so the suite does not pay for it.
  final hasher = BcryptPasswordHasher(rounds: 4);

  group('BcryptPasswordHasher', () {
    group('hash', () {
      test('produces a bcrypt digest', () {
        expect(hasher.hash('hunter2'), startsWith(r'$2a$04$'));
        expect(hasher.hash('hunter2'), hasLength(60));
      });

      // The whole point of the change: the same password must not produce the
      // same digest twice, so a stolen table cannot be attacked in bulk.
      test('salts, so the same password hashes differently each time', () {
        final first = hasher.hash('hunter2');
        final second = hasher.hash('hunter2');

        expect(first, isNot(equals(second)));
        expect(hasher.verify('hunter2', first), isTrue);
        expect(hasher.verify('hunter2', second), isTrue);
      });

      test('never contains the plaintext', () {
        expect(hasher.hash('hunter2'), isNot(contains('hunter2')));
      });

      test('embeds the configured cost', () {
        expect(
          BcryptPasswordHasher(rounds: 6).hash('x'),
          startsWith(r'$2a$06$'),
        );
      });

      test('rejects a cost outside the bcrypt range', () {
        expect(() => BcryptPasswordHasher(rounds: 3), throwsA(isA<Error>()));
        expect(() => BcryptPasswordHasher(rounds: 32), throwsA(isA<Error>()));
      });
    });

    group('verify', () {
      test('accepts the correct password', () {
        expect(hasher.verify('hunter2', hasher.hash('hunter2')), isTrue);
      });

      test('rejects a wrong password', () {
        expect(hasher.verify('hunter3', hasher.hash('hunter2')), isFalse);
      });

      test('is case sensitive', () {
        expect(hasher.verify('Hunter2', hasher.hash('hunter2')), isFalse);
      });

      test('accepts an empty password if that is what was stored', () {
        expect(hasher.verify('', hasher.hash('')), isTrue);
        expect(hasher.verify('x', hasher.hash('')), isFalse);
      });

      test('handles unicode passwords', () {
        final digest = hasher.hash('пароль🔐');
        expect(hasher.verify('пароль🔐', digest), isTrue);
        expect(hasher.verify('пароль', digest), isFalse);
      });

      // bcrypt throws on inputs longer than 72 bytes. Passwords are reduced to
      // a fixed-width token first, so a long passphrase is stored rather than
      // producing a 500 on registration.
      group("passwords longer than bcrypt's 72-byte limit", () {
        final long = 'a' * 200;

        test('hash does not throw', () {
          expect(() => hasher.hash(long), returnsNormally);
        });

        test('round-trips', () {
          expect(hasher.verify(long, hasher.hash(long)), isTrue);
        });

        // Truncation at 72 bytes would make these two indistinguishable.
        test('does not truncate to a common prefix', () {
          final digest = hasher.hash('${'a' * 100}one');
          expect(hasher.verify('${'a' * 100}two', digest), isFalse);
        });

        test('handles a long multibyte password', () {
          final emoji = '🔐' * 50;
          expect(hasher.verify(emoji, hasher.hash(emoji)), isTrue);
        });
      });

      group('returns false rather than throwing for', () {
        final malformed = <String, String>{
          'empty digest': '',
          'not a digest': 'nonsense',
          'truncated bcrypt digest': r'$2a$04$tooshort',
          'unknown algorithm prefix': r'$9z$04$aaaaaaaaaaaaaaaaaaaaaa',
          'hex of the wrong length': '0' * 63,
        };

        for (final entry in malformed.entries) {
          test(entry.key, () {
            expect(hasher.verify('hunter2', entry.value), isFalse);
          });
        }
      });
    });

    group('legacy SHA-256 digests', () {
      final legacy = legacySha256Digest('hunter2');

      test('are still accepted, so existing logins keep working', () {
        expect(hasher.verify('hunter2', legacy), isTrue);
      });

      test('still reject a wrong password', () {
        expect(hasher.verify('hunter3', legacy), isFalse);
      });

      test('are recognisable by shape', () {
        expect(legacy, matches(RegExp(r'^[0-9a-f]{64}$')));
      });
    });

    group('needsRehash', () {
      test('is true for a legacy digest', () {
        expect(hasher.needsRehash(legacySha256Digest('hunter2')), isTrue);
      });

      test('is false for a digest at the configured cost', () {
        expect(hasher.needsRehash(hasher.hash('hunter2')), isFalse);
      });

      // Raising the cost should migrate existing credentials on next login,
      // not just new ones.
      test('is true for a digest at a different cost', () {
        final cheap = BcryptPasswordHasher(rounds: 4).hash('hunter2');
        expect(BcryptPasswordHasher(rounds: 6).needsRehash(cheap), isTrue);
      });

      test('is true for an unrecognised digest', () {
        expect(hasher.needsRehash('nonsense'), isTrue);
      });
    });

    group('verifyAbsentUser', () {
      test('does not throw', () {
        expect(() => hasher.verifyAbsentUser('hunter2'), returnsNormally);
      });

      // It exists to burn the same time as a real verification; if it ever
      // became a no-op the login timing oracle would reopen silently.
      test('costs the same order of magnitude as a real verification', () {
        final digest = hasher.hash('hunter2');

        final realStart = DateTime.now();
        for (var i = 0; i < 5; i++) {
          hasher.verify('hunter2', digest);
        }
        final real = DateTime.now().difference(realStart).inMicroseconds;

        final absentStart = DateTime.now();
        for (var i = 0; i < 5; i++) {
          hasher.verifyAbsentUser('hunter2');
        }
        final absent = DateTime.now().difference(absentStart).inMicroseconds;

        expect(absent, greaterThan(real ~/ 10));
      });
    });

    group('fromEnvironment', () {
      test('falls back to the default cost when BCRYPT_ROUNDS is unset', () {
        expect(
          BcryptPasswordHasher.fromEnvironment().rounds,
          equals(BcryptPasswordHasher.defaultRounds),
        );
      });

      test('defaults to a cost that is slow enough to be useful', () {
        expect(BcryptPasswordHasher.defaultRounds, greaterThanOrEqualTo(12));
      });
    });

    group('parseRounds', () {
      test('reads a valid value', () {
        expect(BcryptPasswordHasher.parseRounds('14'), equals(14));
        expect(BcryptPasswordHasher.parseRounds('31'), equals(31));
      });

      // A misconfigured environment must not quietly weaken hashing, so
      // anything below the default is ignored rather than honoured.
      test('never drops below the default', () {
        for (final raw in ['4', '8', '11', '0', '-1']) {
          expect(
            BcryptPasswordHasher.parseRounds(raw),
            equals(BcryptPasswordHasher.defaultRounds),
            reason: '"$raw" should not lower the cost',
          );
        }
      });

      test('falls back for missing, unparseable or out-of-range values', () {
        for (final raw in [null, '', 'twelve', '12.5', '32', '999']) {
          expect(
            BcryptPasswordHasher.parseRounds(raw),
            equals(BcryptPasswordHasher.defaultRounds),
            reason: '"$raw" should fall back',
          );
        }
      });
    });
  });
}
