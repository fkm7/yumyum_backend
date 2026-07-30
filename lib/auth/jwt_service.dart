import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

const _secret = 'delmer-dev-secret-change-in-production';
const _issuer = 'delmer-backend';

/// The duration for which the access token is valid.
const accessTokenExpiresIn = Duration(days: 1);

/// The duration for which the refresh token is valid.
const refreshTokenExpiresIn = Duration(days: 3);

/// Returns a hashed version of the password using SHA-256.
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

/// Generates a short-lived JWT token for the given user ID (uid).
String generateAccessToken(String uid) {
  final jwt = JWT({'uid': uid, 'token_type': 'access'}, issuer: _issuer);
  return jwt.sign(SecretKey(_secret), expiresIn: accessTokenExpiresIn);
}

/// Generates a long-lived refresh token.
String generateRefreshToken(String uid) {
  final jwt = JWT(
    {
      'uid': uid,
      'token_type': 'refresh',
    },
    issuer: _issuer,
  );
  return jwt.sign(SecretKey(_secret), expiresIn: refreshTokenExpiresIn);
}

/// Returns the uid from a valid access token, or null if invalid/expired.
String? verifyAccessToken(String token) {
  return _verifyTokenByType(token, expectedType: 'access');
}

/// Returns the uid from a valid refresh token, or null if invalid/expired.
String? verifyRefreshToken(String token) {
  return _verifyTokenByType(token, expectedType: 'refresh');
}

String? _verifyTokenByType(String token, {required String expectedType}) {
  try {
    final jwt = JWT.verify(token, SecretKey(_secret));
    final payload = jwt.payload as Map<String, dynamic>;
    final tokenType = payload['token_type'] as String?;
    if (tokenType != expectedType) return null;
    return payload['uid'] as String?;
  } on JWTException {
    return null;
  }
}
