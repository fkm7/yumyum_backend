import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:yumyum_backend/features/auth/domain/token_service.dart';

/// The token kinds issued by [JwtTokenService].
///
/// The kind is embedded in the payload as `token_type` so that a long-lived
/// refresh token cannot be presented where a short-lived access token is
/// expected.
enum TokenType {
  /// A short-lived token used to authenticate API requests.
  access('access'),

  /// A long-lived token used only to mint new access tokens.
  refresh('refresh');

  const TokenType(this.value);

  /// The value stored in the `token_type` claim.
  final String value;
}

/// [TokenService] backed by HMAC-signed JWTs.
///
/// The signing secret and lifetimes are constructor arguments so that tests can
/// supply their own, and so production can supply a real secret from the
/// environment instead of a compiled-in constant.
class JwtTokenService implements TokenService {
  /// Creates a [JwtTokenService] with the given signing [secret] and lifetimes.
  const JwtTokenService({
    required this.secret,
    this.issuer = 'delmer-backend',
    this.accessTokenExpiresIn = const Duration(days: 1),
    this.refreshTokenExpiresIn = const Duration(days: 3),
  });

  /// Creates a [JwtTokenService] configured from the process environment.
  ///
  /// Reads `JWT_SECRET`, falling back to a well-known development secret. The
  /// fallback exists so local development keeps working, and is logged loudly
  /// because it must never be used in production.
  factory JwtTokenService.fromEnvironment() {
    final secret = Platform.environment['JWT_SECRET'];
    if (secret == null || secret.isEmpty) {
      stderr.writeln(
        'WARNING: JWT_SECRET is not set; falling back to the development '
        'secret. Set JWT_SECRET before deploying.',
      );
      return const JwtTokenService(secret: _developmentSecret);
    }
    return JwtTokenService(secret: secret);
  }

  static const _developmentSecret = 'delmer-dev-secret-change-in-production';

  /// The HMAC secret used to sign and verify tokens.
  final String secret;

  /// The `iss` claim written into every issued token.
  final String issuer;

  /// How long a freshly issued access token remains valid.
  @override
  final Duration accessTokenExpiresIn;

  /// How long a freshly issued refresh token remains valid.
  @override
  final Duration refreshTokenExpiresIn;

  /// Generates a short-lived access token for the given user ID (uid).
  @override
  String generateAccessToken(String uid) => _generate(
        {'uid': uid, 'token_type': TokenType.access.value},
        accessTokenExpiresIn,
      );

  /// Generates a long-lived refresh token identified by [tokenId].
  ///
  /// [tokenId] is written as the `jti` claim and must match a stored record,
  /// or the token cannot be verified.
  @override
  String generateRefreshToken(String uid, {required String tokenId}) =>
      _generate(
        {
          'uid': uid,
          'token_type': TokenType.refresh.value,
          'jti': tokenId,
        },
        refreshTokenExpiresIn,
      );

  /// Returns the uid from a valid access token, or null if invalid/expired.
  @override
  String? verifyAccessToken(String token) {
    final payload = _verify(token, TokenType.access);
    final uid = payload?['uid'];
    return uid is String && uid.isNotEmpty ? uid : null;
  }

  /// Returns the claims of a valid refresh token, or null if invalid/expired.
  ///
  /// A token with no `jti` is refused: it predates revocable refresh tokens
  /// and there is no record to check it against, so it cannot be revoked.
  @override
  RefreshTokenClaims? verifyRefreshToken(String token) {
    final payload = _verify(token, TokenType.refresh);
    if (payload == null) return null;

    final uid = payload['uid'];
    final tokenId = payload['jti'];
    if (uid is! String || uid.isEmpty) return null;
    if (tokenId is! String || tokenId.isEmpty) return null;

    return RefreshTokenClaims(uid: uid, tokenId: tokenId);
  }

  String _generate(Map<String, dynamic> claims, Duration expiresIn) {
    final jwt = JWT(claims, issuer: issuer);
    return jwt.sign(SecretKey(secret), expiresIn: expiresIn);
  }

  Map<String, dynamic>? _verify(String token, TokenType expected) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret), issuer: issuer);
      final payload = jwt.payload;
      if (payload is! Map<String, dynamic>) return null;
      if (payload['token_type'] != expected.value) return null;
      return payload;
      // The `is!` guard above matters, as do the claim guards in the callers:
      // a validly-signed token whose payload is not a map, or whose `uid` is
      // not a string, used to reach an unguarded `as` cast and throw a
      // TypeError past the JWTException-only catch, surfacing as a 500. The
      // broad catch is belt-and-braces on top of that: verification never
      // throws, it returns null.
    } catch (_) {
      return null;
    }
  }
}
