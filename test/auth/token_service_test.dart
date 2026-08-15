import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:delmer_backend/auth/token_service.dart';
import 'package:test/test.dart';

const _secret = 'test-secret';

String _base64Url(Map<String, dynamic> value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

void main() {
  const service = TokenService(secret: _secret);

  group('TokenService', () {
    group('access tokens', () {
      test('round-trips the uid', () {
        final token = service.generateAccessToken('user-1');
        expect(service.verifyAccessToken(token), equals('user-1'));
      });

      test('is rejected by verifyRefreshToken', () {
        final token = service.generateAccessToken('user-1');
        expect(service.verifyRefreshToken(token), isNull);
      });
    });

    group('refresh tokens', () {
      test('round-trips the uid', () {
        final token = service.generateRefreshToken('user-1', tokenId: 'jti-1');
        expect(service.verifyRefreshToken(token)?.uid, equals('user-1'));
      });

      test('round-trips the token id', () {
        final token = service.generateRefreshToken('user-1', tokenId: 'jti-1');
        expect(service.verifyRefreshToken(token)?.tokenId, equals('jti-1'));
      });

      // Tokens minted before revocation existed carry no jti, so there is no
      // record to check them against. Refusing them is deliberate: accepting
      // them would leave unrevocable tokens in circulation for their full
      // lifetime. Existing sessions have to log in again.
      test('is rejected when it carries no jti', () {
        final token = JWT({'uid': 'user-1', 'token_type': 'refresh'})
            .sign(SecretKey(_secret));
        expect(service.verifyRefreshToken(token), isNull);
      });

      test('is rejected when the jti is empty', () {
        final token = service.generateRefreshToken('user-1', tokenId: '');
        expect(service.verifyRefreshToken(token), isNull);
      });

      test('is rejected when the jti is not a string', () {
        final token = JWT({'uid': 'user-1', 'token_type': 'refresh', 'jti': 42})
            .sign(SecretKey(_secret));
        expect(service.verifyRefreshToken(token), isNull);
      });

      // This is the check that stops a long-lived refresh token from being
      // used as an access token against the API.
      test('is rejected by verifyAccessToken', () {
        final token = service.generateRefreshToken('user-1', tokenId: 'jti-1');
        expect(service.verifyAccessToken(token), isNull);
      });
    });

    group('expiry', () {
      test('returns null for an expired access token', () {
        const expired = TokenService(
          secret: _secret,
          accessTokenExpiresIn: Duration(seconds: -1),
        );
        final token = expired.generateAccessToken('user-1');
        expect(service.verifyAccessToken(token), isNull);
      });

      test('returns null for an expired refresh token', () {
        const expired = TokenService(
          secret: _secret,
          refreshTokenExpiresIn: Duration(seconds: -1),
        );
        final token = expired.generateRefreshToken('user-1', tokenId: 'jti-1');
        expect(service.verifyRefreshToken(token), isNull);
      });

      test('honours a custom lifetime', () {
        const short = TokenService(
          secret: _secret,
          accessTokenExpiresIn: Duration(minutes: 5),
        );
        expect(short.accessTokenExpiresIn.inSeconds, equals(300));
        expect(short.verifyAccessToken(short.generateAccessToken('u')), 'u');
      });
    });

    group('fromEnvironment', () {
      // JWT_SECRET is normally unset in tests, so this exercises the
      // development fallback; when CI sets one, the configured branch runs
      // instead. Either way the service must come back usable.
      test('returns a working service', () {
        final fromEnv = TokenService.fromEnvironment();
        final token = fromEnv.generateAccessToken('user-1');

        expect(fromEnv.secret, isNotEmpty);
        expect(fromEnv.verifyAccessToken(token), equals('user-1'));
      });

      test('does not sign with the test secret', () {
        final fromEnv = TokenService.fromEnvironment();
        final token = fromEnv.generateAccessToken('user-1');

        expect(service.verifyAccessToken(token), isNull);
      });
    });

    group('signature and issuer', () {
      test('rejects a token signed with a different secret', () {
        const attacker = TokenService(secret: 'not-the-real-secret');
        final token = attacker.generateAccessToken('user-1');
        expect(service.verifyAccessToken(token), isNull);
      });

      test('rejects a token issued by a different issuer', () {
        const other = TokenService(secret: _secret, issuer: 'somewhere-else');
        final token = other.generateAccessToken('user-1');
        expect(service.verifyAccessToken(token), isNull);
      });
    });

    group('malformed input returns null rather than throwing', () {
      // These all fail inside JWT.verify, which raises JWTException, so they
      // were already handled. They are pinned here as regression cover.
      final malformed = <String, String>{
        'empty string': '',
        'not a jwt': 'abc',
        'wrong segment count': 'a.b',
        'non-base64 segments': '!!!.???.***',
        'valid base64, not json': '${base64Url.encode(utf8.encode('x'))}.a.b',
      };

      for (final entry in malformed.entries) {
        test(entry.key, () {
          expect(service.verifyAccessToken(entry.value), isNull);
          expect(service.verifyRefreshToken(entry.value), isNull);
        });
      }

      test('unsigned "alg: none" token', () {
        final header = _base64Url({'alg': 'none', 'typ': 'JWT'});
        final payload = _base64Url({'uid': 'admin', 'token_type': 'access'});
        expect(service.verifyAccessToken('$header.$payload.'), isNull);
      });

      test('token with a missing uid claim', () {
        const noUid = TokenService(secret: _secret);
        final token = noUid.generateAccessToken('');
        expect(service.verifyAccessToken(token), isNull);
      });
    });

    // These two are the cases the original implementation genuinely got wrong.
    // The signature is valid, so JWT.verify succeeds and returns; the old code
    // then hit `payload as Map<String, dynamic>` / `payload['uid'] as String?`
    // and threw a TypeError straight past the `on JWTException` catch,
    // surfacing as a 500 instead of a 401.
    group('validly-signed tokens with an unexpected payload shape', () {
      test('payload is not a map', () {
        final token = JWT('i-am-not-a-map').sign(SecretKey(_secret));
        expect(service.verifyAccessToken(token), isNull);
      });

      test('uid claim is not a string', () {
        final token =
            JWT({'uid': 42, 'token_type': 'access'}).sign(SecretKey(_secret));
        expect(service.verifyAccessToken(token), isNull);
      });
    });
  });
}
