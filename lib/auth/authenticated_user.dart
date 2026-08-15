import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/token_service.dart';

/// The identity established by [authMiddleware] for the current request.
class AuthenticatedUser {
  /// Constructs an [AuthenticatedUser] for the given [uid].
  const AuthenticatedUser(this.uid);

  /// The uid carried by the presented access token.
  final String uid;
}

/// Returns the uid carried by a valid `Authorization: Bearer <token>` header,
/// or null when the header is absent, malformed, or the token does not verify.
///
/// The scheme is matched case-insensitively, per RFC 7235.
String? bearerUid(RequestContext context, TokenService tokens) {
  final header = context.request.headers['Authorization'];
  if (header == null) return null;

  final separator = header.indexOf(' ');
  if (separator < 0) return null;
  if (header.substring(0, separator).toLowerCase() != 'bearer') return null;

  final token = header.substring(separator + 1).trim();
  if (token.isEmpty) return null;

  return tokens.verifyAccessToken(token);
}

/// Rejects requests that do not carry a valid access token, and provides an
/// [AuthenticatedUser] to everything downstream.
///
/// Handlers behind this middleware can safely read an [AuthenticatedUser] off
/// the context without re-checking, because an unauthenticated request never
/// reaches them.
Middleware authMiddleware() {
  return (handler) {
    return (context) async {
      final uid = bearerUid(context, context.read<TokenService>());
      if (uid == null) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'Unauthorized'},
        );
      }
      return handler(
        context.provide<AuthenticatedUser>(() => AuthenticatedUser(uid)),
      );
    };
  };
}
