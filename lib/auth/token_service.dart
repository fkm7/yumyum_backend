import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// The token kinds issued by [TokenService].
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

/// Issues and verifies JWTs.
///
/// The signing secret and lifetimes are constructor arguments so that tests can
/// supply their own, and so production can supply a real secret from the
/// environment instead of a compiled-in constant.
class TokenService {
  /// Creates a [TokenService] with the given signing [secret] and lifetimes.
  const TokenService({
    required this.secret,
    this.issuer = 'delmer-backend',
    this.accessTokenExpiresIn = const Duration(days: 1),
    this.refreshTokenExpiresIn = const Duration(days: 3),
  });

  /// Creates a [TokenService] configured from the process environment.
  ///
  /// Reads `JWT_SECRET`, falling back to a well-known development secret. The
  /// fallback exists so local development keeps working, and is logged loudly
  /// because it must never be used in production.
  factory TokenService.fromEnvironment() {
    final secret = Platform.environment['JWT_SECRET'];
    if (secret == null || secret.isEmpty) {
      stderr.writeln(
        'WARNING: JWT_SECRET is not set; falling back to the development '
        'secret. Set JWT_SECRET before deploying.',
      );
      return const TokenService(secret: _developmentSecret);
    }
    return TokenService(secret: secret);
  }

  static const _developmentSecret = 'delmer-dev-secret-change-in-production';

  /// The HMAC secret used to sign and verify tokens.
  final String secret;

  /// The `iss` claim written into every issued token.
  final String issuer;

  /// How long a freshly issued access token remains valid.
  final Duration accessTokenExpiresIn;

  /// How long a freshly issued refresh token remains valid.
  final Duration refreshTokenExpiresIn;

  /// Generates a short-lived access token for the given user ID (uid).
  String generateAccessToken(String uid) =>
      _generate(uid, TokenType.access, accessTokenExpiresIn);

  /// Generates a long-lived refresh token for the given user ID (uid).
  String generateRefreshToken(String uid) =>
      _generate(uid, TokenType.refresh, refreshTokenExpiresIn);

  /// Returns the uid from a valid access token, or null if invalid/expired.
  String? verifyAccessToken(String token) => _verify(token, TokenType.access);

  /// Returns the uid from a valid refresh token, or null if invalid/expired.
  String? verifyRefreshToken(String token) => _verify(token, TokenType.refresh);

  String _generate(String uid, TokenType type, Duration expiresIn) {
    final jwt = JWT({'uid': uid, 'token_type': type.value}, issuer: issuer);
    return jwt.sign(SecretKey(secret), expiresIn: expiresIn);
  }

  String? _verify(String token, TokenType expected) {
    try {
      final jwt = JWT.verify(token, SecretKey(secret), issuer: issuer);
      final payload = jwt.payload;
      if (payload is! Map<String, dynamic>) return null;
      if (payload['token_type'] != expected.value) return null;
      final uid = payload['uid'];
      if (uid is! String || uid.isEmpty) return null;
      return uid;
      // The `is!` guards above matter: a validly-signed token whose payload is
      // not a map, or whose `uid` is not a string, used to reach an unguarded
      // `as` cast and throw a TypeError past the JWTException-only catch,
      // surfacing as a 500. The broad catch is belt-and-braces on top of that:
      // verification never throws, it returns null.
    } catch (_) {
      return null;
    }
  }
}
