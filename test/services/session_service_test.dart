import 'package:yumyum_backend/auth/token_service.dart';
import 'package:yumyum_backend/models/refresh_token_record.dart';
import 'package:yumyum_backend/models/user.dart';
import 'package:yumyum_backend/services/session_service.dart';
import 'package:test/test.dart';

import '../helpers/fakes.dart';

const _tokens = TokenService(secret: 'test-secret');

const _user = User(
  uid: 'user-1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  email: 'ada@example.com',
  photoUrl: '',
);

class _Harness {
  _Harness();

  final refreshTokens = InMemoryRefreshTokenRepository();
  final users = StubUserRepository(_user);
  DateTime now = DateTime.utc(2026, 8, 15, 12);

  SessionService get service => SessionService(
        tokenService: _tokens,
        refreshTokenRepository: refreshTokens,
        userRepository: users,
        now: () => now,
      );

  RefreshTokenRecord recordFor(String refreshToken) {
    final claims = _tokens.verifyRefreshToken(refreshToken)!;
    return refreshTokens.records[claims.tokenId]!;
  }
}

void main() {
  group('SessionService', () {
    group('start', () {
      test('issues a usable pair', () async {
        final harness = _Harness();
        final pair = await harness.service.start('user-1');

        expect(_tokens.verifyAccessToken(pair.accessToken), equals('user-1'));
        expect(
          _tokens.verifyRefreshToken(pair.refreshToken)?.uid,
          equals('user-1'),
        );
      });

      // Without a stored record the token cannot be revoked, which is the
      // whole point of the change.
      test('stores a record for the refresh token', () async {
        final harness = _Harness();
        final pair = await harness.service.start('user-1');

        final record = harness.recordFor(pair.refreshToken);
        expect(record.userId, equals('user-1'));
        expect(record.isRevoked, isFalse);
        expect(record.issuedAt, equals(harness.now));
        expect(
          record.expiresAt,
          equals(harness.now.add(_tokens.refreshTokenExpiresIn)),
        );
      });

      test('begins a separate family per login', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');
        final second = await harness.service.start('user-1');

        expect(
          harness.recordFor(first.refreshToken).familyId,
          isNot(equals(harness.recordFor(second.refreshToken).familyId)),
        );
      });

      // Logging out on one device must not sign the user out everywhere.
      test('leaves other sessions alone when one is revoked', () async {
        final harness = _Harness();
        final phone = await harness.service.start('user-1');
        final laptop = await harness.service.start('user-1');

        await harness.service.revoke(phone.refreshToken);

        expect(harness.recordFor(phone.refreshToken).isRevoked, isTrue);
        expect(harness.recordFor(laptop.refreshToken).isRevoked, isFalse);
      });
    });

    group('rotate', () {
      test('issues a new pair', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');

        final result = await harness.service.rotate(first.refreshToken);

        expect(result, isA<RefreshSucceeded>());
        final next = (result as RefreshSucceeded).tokens;
        expect(next.refreshToken, isNot(equals(first.refreshToken)));
        expect(_tokens.verifyAccessToken(next.accessToken), equals('user-1'));
      });

      // The gap this whole change closes: the presented token used to stay
      // valid forever after being exchanged.
      test('revokes the presented token', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');

        await harness.service.rotate(first.refreshToken);

        expect(harness.recordFor(first.refreshToken).isRevoked, isTrue);
      });

      test('refuses the presented token a second time', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');

        await harness.service.rotate(first.refreshToken);
        final replay = await harness.service.rotate(first.refreshToken);

        expect(replay, isA<RefreshReuseDetected>());
      });

      test('records which token superseded it', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');

        final result = await harness.service.rotate(first.refreshToken)
            as RefreshSucceeded;

        final successor = harness.recordFor(result.tokens.refreshToken);
        expect(
          harness.recordFor(first.refreshToken).replacedBy,
          equals(successor.id),
        );
      });

      test('keeps the successor in the same family', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');

        final result = await harness.service.rotate(first.refreshToken)
            as RefreshSucceeded;

        expect(
          harness.recordFor(result.tokens.refreshToken).familyId,
          equals(harness.recordFor(first.refreshToken).familyId),
        );
      });

      test('rotates repeatedly down a chain', () async {
        final harness = _Harness();
        var pair = await harness.service.start('user-1');

        for (var i = 0; i < 5; i++) {
          final result = await harness.service.rotate(pair.refreshToken);
          expect(result, isA<RefreshSucceeded>());
          pair = (result as RefreshSucceeded).tokens;
        }

        expect(harness.refreshTokens.records, hasLength(6));
      });

      group('rejects', () {
        test('a malformed token', () async {
          final harness = _Harness();
          expect(
            await harness.service.rotate('nonsense'),
            isA<RefreshRejected>(),
          );
        });

        test('an access token', () async {
          final harness = _Harness();
          final access = _tokens.generateAccessToken('user-1');
          expect(
            await harness.service.rotate(access),
            isA<RefreshRejected>(),
          );
        });

        // Tokens issued before revocation existed have no jti, so there is no
        // record to check them against. They are refused rather than
        // grandfathered, which would leave unrevocable tokens in circulation.
        test('a token with no jti claim', () async {
          final harness = _Harness();
          final legacy = const TokenService(secret: 'test-secret')
              .generateRefreshToken('user-1', tokenId: '');

          expect(
            await harness.service.rotate(legacy),
            isA<RefreshRejected>(),
          );
        });

        test('a correctly signed token with no stored record', () async {
          final harness = _Harness();
          final orphan =
              _tokens.generateRefreshToken('user-1', tokenId: 'never-issued');

          expect(
            await harness.service.rotate(orphan),
            isA<RefreshRejected>(),
          );
        });

        test('a token whose record belongs to a different user', () async {
          final harness = _Harness();
          final pair = await harness.service.start('user-1');
          final claims = _tokens.verifyRefreshToken(pair.refreshToken)!;
          final forged = _tokens.generateRefreshToken(
            'someone-else',
            tokenId: claims.tokenId,
          );

          expect(
            await harness.service.rotate(forged),
            isA<RefreshRejected>(),
          );
        });

        test('an expired token', () async {
          final harness = _Harness();
          final pair = await harness.service.start('user-1');

          harness.now = harness.now
              .add(_tokens.refreshTokenExpiresIn)
              .add(const Duration(seconds: 1));

          expect(
            await harness.service.rotate(pair.refreshToken),
            isA<RefreshRejected>(),
          );
        });

        test('a token revoked by logout', () async {
          final harness = _Harness();
          final pair = await harness.service.start('user-1');

          await harness.service.revoke(pair.refreshToken);

          // Revoked-then-presented is indistinguishable from replay, and is
          // treated the same way.
          expect(
            await harness.service.rotate(pair.refreshToken),
            isA<RefreshReuseDetected>(),
          );
        });
      });

      test('reports a missing user separately', () async {
        final harness = _Harness();
        final pair = await harness.service.start('user-1');
        harness.users.user = null;

        expect(
          await harness.service.rotate(pair.refreshToken),
          isA<RefreshUserMissing>(),
        );
      });

      test('does not rotate when the user is missing', () async {
        final harness = _Harness();
        final pair = await harness.service.start('user-1');
        harness.users.user = null;

        await harness.service.rotate(pair.refreshToken);

        expect(harness.recordFor(pair.refreshToken).isRevoked, isFalse);
        expect(harness.refreshTokens.records, hasLength(1));
      });
    });

    group('reuse detection', () {
      // Replaying a rotated token means a copy escaped, so the successors it
      // spawned are assumed compromised too.
      test('revokes every token in the family', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');
        final second = (await harness.service.rotate(first.refreshToken)
                as RefreshSucceeded)
            .tokens;
        final third = (await harness.service.rotate(second.refreshToken)
                as RefreshSucceeded)
            .tokens;

        await harness.service.rotate(first.refreshToken);

        expect(harness.recordFor(third.refreshToken).isRevoked, isTrue);
        expect(
          harness.refreshTokens.records.values.every((r) => r.isRevoked),
          isTrue,
        );
      });

      test('makes the live token unusable afterwards', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');
        final second = (await harness.service.rotate(first.refreshToken)
                as RefreshSucceeded)
            .tokens;

        await harness.service.rotate(first.refreshToken);

        expect(
          await harness.service.rotate(second.refreshToken),
          isA<RefreshReuseDetected>(),
        );
      });

      test('names the revoked family', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');
        await harness.service.rotate(first.refreshToken);

        final result = await harness.service.rotate(first.refreshToken);

        expect(
          (result as RefreshReuseDetected).familyId,
          equals(harness.recordFor(first.refreshToken).familyId),
        );
      });

      test('leaves an unrelated session working', () async {
        final harness = _Harness();
        final compromised = await harness.service.start('user-1');
        final other = await harness.service.start('user-1');

        await harness.service.rotate(compromised.refreshToken);
        await harness.service.rotate(compromised.refreshToken);

        expect(
          await harness.service.rotate(other.refreshToken),
          isA<RefreshSucceeded>(),
        );
      });
    });

    group('revoke', () {
      test('revokes the whole family, not just the presented token', () async {
        final harness = _Harness();
        final first = await harness.service.start('user-1');
        final second = (await harness.service.rotate(first.refreshToken)
                as RefreshSucceeded)
            .tokens;

        await harness.service.revoke(second.refreshToken);

        expect(
          harness.refreshTokens.records.values.every((r) => r.isRevoked),
          isTrue,
        );
      });

      test('makes a subsequent refresh fail', () async {
        final harness = _Harness();
        final pair = await harness.service.start('user-1');

        await harness.service.revoke(pair.refreshToken);

        expect(
          await harness.service.rotate(pair.refreshToken),
          isNot(isA<RefreshSucceeded>()),
        );
      });

      // Logout must not become a probe for which tokens exist, so unknown and
      // malformed input is accepted silently.
      test('is silent for unknown, malformed and already-revoked tokens',
          () async {
        final harness = _Harness();
        final pair = await harness.service.start('user-1');
        await harness.service.revoke(pair.refreshToken);

        for (final token in [
          'nonsense',
          '',
          _tokens.generateAccessToken('user-1'),
          _tokens.generateRefreshToken('user-1', tokenId: 'never-issued'),
          pair.refreshToken,
        ]) {
          await expectLater(harness.service.revoke(token), completes);
        }
      });

      test("does not revoke another user's family", () async {
        final harness = _Harness();
        final pair = await harness.service.start('user-1');
        final claims = _tokens.verifyRefreshToken(pair.refreshToken)!;
        final forged = _tokens.generateRefreshToken(
          'someone-else',
          tokenId: claims.tokenId,
        );

        await harness.service.revoke(forged);

        expect(harness.recordFor(pair.refreshToken).isRevoked, isFalse);
      });
    });
  });
}
